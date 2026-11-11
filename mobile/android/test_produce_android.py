#!/usr/bin/env python3
"""Dry checks of produce_android.py for both source profiles against real git objects (no toolchain,
no build, no LFS fetch).

  legacy    ZANO_LEGACY_CORE_GIT must name a core repository holding the legacy composition commit;
            without it the legacy cases are skipped, and the skip says so.
  snapshot  ZANO_SNAPSHOT_CORE_GIT (default: this library's Zano checkout) must be a checkout at the
            snapshot root with contrib/jwt-cpp and contrib/miniupnp initialized.
Usage: ZANO_LEGACY_CORE_GIT=CORE_REPO python3 -I mobile/android/test_produce_android.py -v
"""
import copy
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("produce_android", HERE / "produce_android.py")
recipe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipe)
LEGACY_CORE = os.environ.get("ZANO_LEGACY_CORE_GIT")
SNAPSHOT_CORE = os.environ.get("ZANO_SNAPSHOT_CORE_GIT", str(HERE.parents[1] / "Zano"))
LEGACY_LABEL = "299bf172e8428042919b48bfa1cedfcd9ede139a-native-snapshot-compat-v1"


def listed(repo, rev, prefix=""):
    """{path: (mode, object)} of every tree entry under rev from `git ls-tree` alone (no blob is read)."""
    out = subprocess.run(["git", "-C", str(repo), "ls-tree", "-r", "-z", rev], stdout=subprocess.PIPE, check=True).stdout
    entries = {}
    for record in out.decode().split("\0"):
        if record:
            meta, path = record.split("\t", 1)
            mode, _kind, obj = meta.split()
            entries[prefix + path] = (mode, obj)
    return entries


def expected_build_source(repo, rev, never=()):
    """Blobs of rev plus the pinned trees of the required submodules, as (mode, blob id) by path."""
    entries = listed(repo, rev)
    files = {p: v for p, v in entries.items() if v[0] != "160000" and p not in never}
    for link in recipe.REQUIRED_SUBMODULES:
        files.update(listed(Path(repo) / link, entries[link][1], link + "/"))
    return files, sorted(p for p, v in entries.items() if v[0] == "160000" and p not in recipe.REQUIRED_SUBMODULES)


def materialized(root):
    """(mode, blob id) by path of every file under root; any symlink or special file fails."""
    found = {}
    for path in sorted(Path(root).rglob("*")):
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise AssertionError("not a regular file or directory: %s" % path)
        if path.is_file():
            data = path.read_bytes()
            mode = "100755" if os.stat(str(path)).st_mode & 0o111 else "100644"
            found[path.relative_to(root).as_posix()] = (mode, hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest())
    return found


@unittest.skipUnless(LEGACY_CORE, "ZANO_LEGACY_CORE_GIT names no core repository with the legacy composition")
class AndroidRecipeDryChecks(unittest.TestCase):
    def setUp(self):
        self.manifest, self.spec, self.inputs = recipe.load("legacy")

    def test_every_non_built_input_resolves_to_its_pin(self):
        rows = recipe.pinned_inputs(LEGACY_CORE, self.inputs)
        self.assertEqual(len(rows), len(self.inputs["headers"]) + len(self.inputs["dependencies"]))
        self.assertEqual(sum(isinstance(v, tuple) for _, v in rows), 14)
        outputs = {o for o, _ in rows}
        self.assertFalse(outputs & set(self.inputs["builtOutputs"]), "built outputs carry no pin")

    def test_source_must_be_the_declared_composition(self):
        head = recipe.git(LEGACY_CORE, "rev-parse", "HEAD").decode().strip()
        if head == self.spec["sourceCommit"]:
            self.skipTest("core checkout is at the declared commit")
        with self.assertRaisesRegex(SystemExit, "not the declared composition"):
            recipe.check_source(LEGACY_CORE, self.spec)

    def test_changed_header_pin_is_refused(self):
        inputs = copy.deepcopy(self.inputs)
        inputs["headers"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(SystemExit, "header differs"):
            recipe.pinned_inputs(LEGACY_CORE, inputs)

    def test_moved_lfs_pointer_is_refused(self):
        inputs = copy.deepcopy(self.inputs)
        dep = next(d for d in inputs["dependencies"] if "pointerBlob" in d)
        dep["pointerBlob"] = "0" * 40
        with self.assertRaisesRegex(SystemExit, "LFS pointer moved"):
            recipe.pinned_inputs(LEGACY_CORE, inputs)

    def test_wrong_ndk_is_refused(self):
        with tempfile.TemporaryDirectory() as ndk:
            Path(ndk, "source.properties").write_text("Pkg.Revision = 26.3.11579264\n")
            with self.assertRaisesRegex(SystemExit, "NDK must be 27.1.12297006"):
                recipe.toolchain(self.spec, ndk, "cmake")

    def test_existing_output_is_refused_before_any_work(self):
        with tempfile.TemporaryDirectory() as out:
            with self.assertRaisesRegex(SystemExit, "--out must not exist"):
                recipe.main(["build", "--profile", "legacy", "--source", LEGACY_CORE, "--ndk", "/nonexistent",
                             "--cmake", "cmake", "--out", out])

    def test_configure_identity(self):
        args = recipe.configure_args(self.spec, Path("/s"), Path("/b"), Path("/d"), "/ndk")
        for flag in ("-DCMAKE_SYSTEM_VERSION=24", "-DCMAKE_ANDROID_ARCH_ABI=arm64-v8a",
                     "-DCMAKE_ANDROID_STL_TYPE=c++_shared", "-DCMAKE_CXX_STANDARD=17", "-DTESTNET=ON",
                     "-DBUILD_TESTS=OFF", "-DDISABLE_TOR=ON", "-DGIT=OFF", "-DCOMMIT_ID_IN_VERSION=ON",
                     "-DCOMMIT=" + LEGACY_LABEL):
            self.assertIn(flag, args)
        self.assertEqual(recipe.TARGETS, ("wallet", "currency_core", "crypto", "common", "zlibstatic"))

    def test_build_source_never_holds_the_legacy_js_examples(self):
        listing = listed(LEGACY_CORE, self.spec["sourceCommit"])
        for rel in recipe.NEVER_MATERIALIZED:
            self.assertIn(rel, listing, "the legacy tree lists %s" % rel)
        expected, empty = expected_build_source(LEGACY_CORE, self.spec["sourceCommit"], recipe.NEVER_MATERIALIZED)
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "source"
            recipe.materialize_source(LEGACY_CORE, self.spec, self.manifest["appComposition"]["forbiddenPaths"], dest)
            self.assertEqual(materialized(dest), expected)
            for link in empty:
                self.assertEqual(os.listdir(str(dest / link)), [])


class SnapshotAndroidRecipeDryChecks(unittest.TestCase):
    def setUp(self):
        self.manifest, self.spec, self.inputs = recipe.load("snapshot")
        self.root = self.manifest["core"]["commit"]
        self.legacy_manifest = json.loads(recipe.PROFILES["legacy"][0].read_text())
        self.legacy_inputs = json.loads(recipe.PROFILES["legacy"][1].read_text())
        self.inputs_sha = recipe.sha256(recipe.PROFILES["snapshot"][1].read_bytes())
        self.script_sha = recipe.sha256(recipe.SCRIPT.read_bytes())

    def admit(self, manifest=None, inputs=None, inputs_sha=None, script_sha=None, profile="snapshot"):
        return recipe.admit(profile, manifest or self.manifest, inputs or self.inputs,
                            inputs_sha or self.inputs_sha, script_sha or self.script_sha)

    def plant(self, root, rel):
        """Creates root/rel (and missing parents) for this test only; each is removed by a cleanup."""
        target = Path(root) / rel
        if os.path.lexists(str(target)):
            self.fail("refusing to overwrite an existing checkout path: " + rel)
        created, parent = [], target.parent
        while not parent.exists():
            created.append(parent)
            parent = parent.parent
        for directory in reversed(created):
            directory.mkdir()
            self.addCleanup(directory.rmdir)
        target.write_bytes(b"#error planted outside git by the F1 build-source proof\n")
        self.addCleanup(target.unlink)

    def test_build_source_holds_exactly_the_git_objects(self):
        core = Path(SNAPSHOT_CORE)
        extras = ("contrib/zlib/zconf.h",                                   # untracked: the forbidden zlib header
                  "src/wallet/f1_untracked_extra.h",                        # untracked core source
                  "src/.idea/f1_ignored_extra.h",                           # ignored core source (.idea)
                  "build-f1-proof/f1_ignored_extra.h",                      # ignored top-level build dir (/build*)
                  "contrib/jwt-cpp/include/jwt-cpp/f1_untracked_extra.h",   # untracked in a required submodule
                  "contrib/jwt-cpp/include/.vs/f1_ignored_extra.h",         # ignored in a required submodule (.vs/)
                  "contrib/bitcoin-secp256k1/include/f1_extra.h")           # inside an uninitialized gitlink
        for rel in extras:
            self.plant(core, rel)
        status = recipe.git(core, "status", "--porcelain", "--untracked-files=all", "--ignored").decode().splitlines()
        for line in ("?? contrib/zlib/zconf.h", "?? src/wallet/f1_untracked_extra.h"):
            self.assertIn(line, status)
        self.assertTrue(any(l.startswith("!! src/.idea/") for l in status), "the core ignores src/.idea")
        self.assertTrue(any(l.startswith("!! build-f1-proof/") for l in status), "the core ignores /build*")
        sub = recipe.git(core / "contrib/jwt-cpp", "status", "--porcelain", "--untracked-files=all", "--ignored")
        sub = sub.decode().splitlines()
        self.assertIn("?? include/jwt-cpp/f1_untracked_extra.h", sub)
        self.assertTrue(any(l.startswith("!! include/.vs/") for l in sub), "jwt-cpp ignores .vs/")
        expected, empty = expected_build_source(core, self.root)
        self.assertEqual(empty, ["contrib/bitcoin-secp256k1", "src/gui/qt-daemon/layout"])
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "source"
            census = recipe.materialize_source(core, self.spec, self.manifest["appComposition"]["forbiddenPaths"], dest)
            self.assertEqual(materialized(dest), expected, "the build source is exactly the git objects")
            self.assertEqual(census["files"], len(expected))
            for rel in extras:
                self.assertFalse(os.path.lexists(str(dest / rel)), rel)
            for link in empty:
                self.assertEqual(os.listdir(str(dest / link)), [])
            args = recipe.configure_args(self.spec, dest, Path("/b"), Path("/d"), "/ndk")
            self.assertEqual(args[:2], ["-S", str(dest)])
            with self.assertRaisesRegex(SystemExit, "not a git checkout"):
                recipe.configure_args(self.spec, core, Path("/b"), Path("/d"), "/ndk")

    def test_build_source_refusals(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(SystemExit, "forbidden path CMakeLists.txt"):
                recipe.materialize_source(SNAPSHOT_CORE, self.spec, [{"path": "CMakeLists.txt"}], Path(tmp) / "a")
            with self.assertRaisesRegex(SystemExit, "already exists"):
                recipe.materialize_source(SNAPSHOT_CORE, self.spec, [], Path(tmp))
            legacy_spec = self.legacy_manifest["compositions"][recipe.COMPOSITION]
            with self.assertRaisesRegex(SystemExit, "git ls-tree failed"):
                recipe.materialize_source(SNAPSHOT_CORE, legacy_spec, [], Path(tmp) / "b")

    def test_source_and_every_non_built_input_resolve_at_the_root(self):
        recipe.check_source(SNAPSHOT_CORE, self.spec)
        self.assertEqual(self.spec["sourceCommit"], self.root)
        rows = recipe.pinned_inputs(SNAPSHOT_CORE, self.inputs)
        self.assertEqual(len(rows), len(self.inputs["headers"]) + len(self.inputs["dependencies"]))
        self.assertEqual(len(rows) + len(self.inputs["builtOutputs"]), 308)
        self.assertEqual(sum(isinstance(v, tuple) for _, v in rows), 14)
        self.assertFalse({o for o, _ in rows} & set(self.inputs["builtOutputs"]), "built outputs carry no pin")

    def test_legacy_composition_cannot_resolve_from_the_snapshot_checkout(self):
        legacy_spec = self.legacy_manifest["compositions"][recipe.COMPOSITION]
        with self.assertRaisesRegex(SystemExit, "not the declared composition"):
            recipe.check_source(SNAPSHOT_CORE, legacy_spec)
        with self.assertRaisesRegex(SystemExit, "git cat-file failed"):
            recipe.pinned_inputs(SNAPSHOT_CORE, self.legacy_inputs)

    def test_explicit_profile_is_required(self):
        with self.assertRaisesRegex(SystemExit, "explicit source profile"):
            recipe.load()
        with self.assertRaisesRegex(SystemExit, "explicit source profile"):
            recipe.load("current")
        with self.assertRaises(SystemExit):
            recipe.main(["plan", "--source", SNAPSHOT_CORE])

    def test_mixed_profile_files_are_refused(self):
        with self.assertRaisesRegex(SystemExit, "different source commits"):
            self.admit(inputs=self.legacy_inputs)
        with self.assertRaisesRegex(SystemExit, "different source commits"):
            self.admit(manifest=self.legacy_manifest)
        with self.assertRaisesRegex(SystemExit, "retained lineage"):
            self.admit(profile="legacy")
        with self.assertRaisesRegex(SystemExit, "snapshot manifest and the snapshot inputs"):
            self.admit(inputs=dict(self.inputs, sourceProfile=None))

    def test_changed_inputs_script_and_header_pins_are_refused(self):
        with self.assertRaisesRegex(SystemExit, "inputs are not the bytes the profile pins"):
            self.admit(inputs_sha="0" * 64)
        with self.assertRaisesRegex(SystemExit, "not the script the snapshot profile pins"):
            self.admit(script_sha="0" * 64)
        inputs = copy.deepcopy(self.inputs)
        next(h for h in inputs["headers"] if h["from"] == "core")["sha256"] = "0" * 64
        with self.assertRaisesRegex(SystemExit, "header differs"):
            recipe.pinned_inputs(SNAPSHOT_CORE, inputs)
        inputs = copy.deepcopy(self.inputs)
        next(d for d in inputs["dependencies"] if "pointerBlob" in d)["pointerBlob"] = "0" * 40
        with self.assertRaisesRegex(SystemExit, "LFS pointer moved"):
            recipe.pinned_inputs(SNAPSHOT_CORE, inputs)

    def test_old_version_root_mismatch_and_evidence_are_refused(self):
        old = self.legacy_manifest["compositions"][recipe.COMPOSITION]["expectedVersion"]
        for change, needle in ((lambda m: m["compositions"][recipe.COMPOSITION].update(expectedVersion=old), "version"),
                               (lambda m: m["sdkVersion"].update(commitLabel="0" * 40), "version"),
                               (lambda m: m["core"].update(commit="0" * 40), "not the snapshot root"),
                               (lambda m: m["compositions"][recipe.COMPOSITION].update(currentArtifactEvidence={}), "evidence"),
                               (lambda m: m["qualification"].update(status="qualified"), "qualification")):
            manifest = copy.deepcopy(self.manifest)
            change(manifest)
            with self.assertRaisesRegex(SystemExit, needle):
                self.admit(manifest=manifest)

    def test_generated_version_header_must_carry_the_root_version(self):
        template = recipe.git(SNAPSHOT_CORE, "cat-file", "blob", "%s:src/version.h.in" % self.root).decode()
        with tempfile.TemporaryDirectory() as build:
            header = Path(build, "version", "version.h")
            header.parent.mkdir()
            header.write_text(template.replace("@VERSION@", "1.0-g" + LEGACY_LABEL))
            with self.assertRaisesRegex(SystemExit, "carries 2.2.1.506\\[1.0-g%s\\], not" % LEGACY_LABEL):
                recipe.check_version_header(Path(build), self.spec)
            header.write_text(template.replace("@VERSION@", "1.0-g" + self.root))
            recipe.check_version_header(Path(build), self.spec)
            header.write_text(template.replace('#define BUILD_COMMIT_ID "@VERSION@"', ""))
            with self.assertRaisesRegex(SystemExit, "no build identity"):
                recipe.check_version_header(Path(build), self.spec)
        self.assertEqual(self.spec["expectedVersion"], "2.2.1.506[1.0-g%s]" % self.root)

    def test_configure_identity(self):
        args = recipe.configure_args(self.spec, Path("/s"), Path("/b"), Path("/d"), "/ndk")
        for flag in ("-DCMAKE_SYSTEM_VERSION=24", "-DTESTNET=ON", "-DGIT=OFF", "-DCOMMIT_ID_IN_VERSION=ON", "-DREFS=",
                     "-DCOMMIT=" + self.root):
            self.assertIn(flag, args)
        self.assertNotIn("-DCOMMIT=" + LEGACY_LABEL, args)

    def test_existing_output_is_refused_before_any_work(self):
        with tempfile.TemporaryDirectory() as out:
            with self.assertRaisesRegex(SystemExit, "--out must not exist"):
                recipe.main(["build", "--profile", "snapshot", "--source", SNAPSHOT_CORE, "--ndk", "/nonexistent",
                             "--cmake", "cmake", "--out", out])


if __name__ == "__main__":
    unittest.main()

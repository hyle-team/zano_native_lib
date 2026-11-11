#!/usr/bin/env python3
"""The library SDK producer evaluates from this wrapper alone, for an explicit source profile.

Runs the real `plan` entry (closure -> composed snapshot -> admit_snapshot -> header plan) and records
every file Python opens: nothing outside this wrapper and the scratch directory may be read (no
consuming app, its SDK copies, its Android lock or its mount). Refusals cover the profile choice, mixed
profile files, the composition commit and root identity, closure bytes and census, producer
configuration, an old composed stage, the built version, overlay drift and the header closure.
  snapshot  needs Zano at the snapshot root with contrib/jwt-cpp and contrib/miniupnp initialized.
  legacy    needs ZANO_LEGACY_CORE_GIT, a core repository holding the legacy Apple composition with the
            same submodules initialized; without it the legacy cases are skipped, and the skip says so.
No build, toolchain or network.

Run: python3 -B mobile/ios/test_sdk_producer.py -v
"""
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("zano_mobile_sdk_producer_under_test", str(HERE / "sdk_producer.py"))
sdk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sdk)
OPENED = []
LEGACY_CORE = os.environ.get("ZANO_LEGACY_CORE_GIT")
HISTORICAL = ("299bf172e8428042919b48bfa1cedfcd9ede139a", "98131bb6728ea79bb54e6c21a3a83a8bca27d686",
              "fdee56b8f8d9d429848a49aa89d5d0278ba0839a", "e90a4e181fff7ff96ce03ddeda565d07cb5f75e8")


def _audit(event, args):
    if event == "open" and args and isinstance(args[0], (str, bytes, os.PathLike)):
        OPENED.append(os.path.realpath(os.fsdecode(args[0])))


sys.addaudithook(_audit)


def run_plan(argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = sdk.main(argv)
    text = out.getvalue()
    return code, (json.loads(text[text.index("{\n"):]) if code == 0 else None)  # progress lines precede the plan


def unseal(root):
    for d, _dirs, files in os.walk(str(root)):
        os.chmod(d, 0o755)
        for f in files:
            os.chmod(os.path.join(d, f), 0o644)


class ProducerFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(os.path.realpath(tempfile.mkdtemp(prefix="zano-sdk-producer-")))

    @classmethod
    def tearDownClass(cls):
        unseal(cls.tmp)
        shutil.rmtree(str(cls.tmp))

    def fixture(self, name, *extra):
        snapshot = self.tmp / name / "snapshot"
        if not snapshot.exists():
            code, _plan = run_plan(["plan", "--profile", self.profile, "--scratch", str(self.tmp / name)] + list(extra))
            self.assertEqual(code, 0)
        return snapshot

    def assert_plan_reads_only_wrapper_and_scratch(self):
        wrapper, scratch = str(sdk.WRAPPER) + os.sep, str(self.tmp) + os.sep
        outside = sorted({p for p in OPENED if not (p.startswith(wrapper) or p.startswith(scratch))})
        self.assertEqual(outside, [], "the library plan read files outside the wrapper")


class LibrarySdkProducer(ProducerFixture):
    profile = "snapshot"

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.config, cls.config_sha = sdk.load_config("snapshot")
        cls.manifest = json.loads((sdk.WRAPPER / "mobile/zano-mobile-sdk-snapshot.json").read_text())
        cls.apple = cls.manifest["compositions"][sdk.APPLE_COMPOSITION]
        cls.root = cls.manifest["core"]["commit"]
        cls.legacy_closure = json.loads((sdk.WRAPPER / "mobile/ios/closure.json").read_text())

    def test_plan_runs_from_this_wrapper_alone(self):
        del OPENED[:]
        code, plan = run_plan(["plan", "--profile", "snapshot", "--scratch", str(self.tmp / "plan-main")])
        self.assertEqual(code, 0)
        self.assertEqual(plan["profile"], "snapshot")
        self.assertEqual(plan["sourceCommit"], self.root)
        self.assertEqual(plan["expectedVersion"], "2.2.1.506[1.0-g%s]" % self.root)
        self.assertEqual(plan["census"], {k: self.apple["sdkCensus"][k] for k in ("sha256", "fileCount", "totalBytes")})
        self.assertEqual(plan["census"], self.legacy_closure["census"], "the root resolves the closure byte for byte")
        self.assertEqual(plan["deltas"], 21)
        self.assertEqual([o["path"] for o in plan["overlays"]],
                         ["Zano/" + p for p in self.config["composition"]["projectOverlays"]["paths"]])
        self.assertEqual(sum(plan["headerClosure"].values()), 287)
        self.assertEqual(plan["headerClosure"]["boost"], 2)
        self.assert_plan_reads_only_wrapper_and_scratch()

    def test_snapshot_route_needs_no_historical_object(self):
        core = sdk.WRAPPER / "Zano"
        for commit in HISTORICAL:
            proc = subprocess.run(["git", "-C", str(core), "cat-file", "-e", commit], stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE)
            self.assertNotEqual(proc.returncode, 0, commit)
        alternates = sdk.git_bytes(core, "rev-parse", "--git-path", "objects/info/alternates").decode().strip()
        self.assertFalse((core / alternates).exists())
        self.assertEqual(sdk.commit_identity(core, self.root), (self.manifest["core"]["tree"], []))
        code, _plan = run_plan(["plan", "--profile", "legacy", "--scratch", str(self.tmp / "legacy-from-snapshot")])
        self.assertEqual(code, 1, "the legacy closure must not resolve from the snapshot checkout")

    def test_module_names_no_app_path(self):
        source = (HERE / "sdk_producer.py").read_text(encoding="utf-8")
        for needle in ("native/zano", "zano-core", "artifacts.testnet-lifecycle", "source-overlay", "PROJECT ="):
            self.assertNotIn(needle, source)
        for profile in ("legacy", "snapshot"):
            config, _sha = sdk.load_config(profile)
            self.assertEqual(config["composition"]["projectOverlays"]["root"], "Zano")
            self.assertNotIn("closureFrom", config["headers"])
            self.assertEqual(len(config["headers"]["closurePaths"]), 287)
        self.assertNotIn("versionOrigin", self.config)
        self.assertTrue(all(hasattr(sdk, name) for name in sdk.INTERFACE))

    def test_explicit_profile_is_required(self):
        for value in (None, "current"):
            with self.assertRaisesRegex(sdk.Refusal, "explicit source profile"):
                sdk.load_config(value)
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                sdk.main(["plan", "--scratch", str(self.tmp / "no-profile")])
        with self.assertRaisesRegex(sdk.Refusal, "unknown source profile"):
            sdk.profile_of(dict(self.config, sourceProfile="maintained-snapshot-v0"))

    def test_mixed_profile_files_are_refused(self):
        with self.assertRaisesRegex(sdk.Refusal, "not the pinned Apple composition"):
            sdk.admit_closure(self.config, self.config_sha, closure=self.legacy_closure)
        legacy_config, legacy_sha = sdk.load_config("legacy")
        snapshot_closure = sdk.admit_closure(self.config, self.config_sha)["closure"]
        with self.assertRaisesRegex(sdk.Refusal, "not the pinned Apple composition"):
            sdk.admit_closure(legacy_config, legacy_sha, closure=snapshot_closure)
        unlabelled = dict(self.config)
        del unlabelled["sourceProfile"]
        with self.assertRaisesRegex(sdk.Refusal, "another producer configuration"):
            sdk.admit_closure(unlabelled, self.config_sha)
        with self.assertRaisesRegex(sdk.Refusal, "different source profiles"):
            sdk.admit_closure(self.config, self.config_sha, closure={k: v for k, v in snapshot_closure.items()
                                                                     if k != "sourceProfile"})

    def test_other_composition_commit_is_refused(self):
        ctx = sdk.admit_closure(self.config, self.config_sha)
        closure = dict(ctx["closure"], sourceCommit="fdee56b8f8d9d429848a49aa89d5d0278ba0839a")
        with self.assertRaisesRegex(sdk.Refusal, "not the pinned Apple composition"):
            sdk.admit_closure(self.config, self.config_sha, closure=closure)

    def test_other_configuration_is_refused(self):
        with self.assertRaisesRegex(sdk.Refusal, "another producer configuration"):
            sdk.admit_closure(self.config, "0" * 64)

    def test_unpinned_producer_bytes_are_refused(self):
        other = self.tmp / "sdk_producer.py"
        other.write_bytes(sdk.PRODUCER_PATH.read_bytes() + b"\n")
        pinned, sdk.PRODUCER_PATH = sdk.PRODUCER_PATH, other
        try:
            with self.assertRaisesRegex(sdk.Refusal, "not the SDK producer the snapshot profile pins"):
                sdk.admit_closure(self.config, self.config_sha)
        finally:
            sdk.PRODUCER_PATH = pinned

    def test_changed_closure_bytes_and_census_are_refused(self):
        closure = copy.deepcopy(sdk.admit_closure(self.config, self.config_sha)["closure"])
        next(r for r in closure["files"] if r["from"] == "submodule")["sha256"] = "0" * 64
        with self.assertRaisesRegex(sdk.Refusal, "does not resolve to its closure pin"):
            sdk.snapshot_from_closure(self.config, self.config_sha, str(self.tmp / "bytes"), closure=closure)
        closure = copy.deepcopy(sdk.admit_closure(self.config, self.config_sha)["closure"])
        closure["census"]["totalBytes"] += 1
        with self.assertRaisesRegex(sdk.Refusal, "different roots or censuses"):
            sdk.admit_closure(self.config, self.config_sha, closure=closure)

    def test_core_without_the_root_is_refused(self):
        empty = self.tmp / "empty-core"
        empty.mkdir()
        subprocess.run(["git", "-C", str(empty), "init", "-q"], check=True)
        with self.assertRaisesRegex(sdk.Refusal, "git cat-file failed"):
            sdk.admit_closure(self.config, self.config_sha, core=empty)

    def test_old_composed_stage_is_refused_by_the_snapshot_recipe(self):
        snapshot = self.fixture("plan-fixture")
        old = self.tmp / "old-stage" / "snapshot"
        shutil.copytree(str(snapshot), str(old))
        unseal(old)
        legacy_config, legacy_sha = sdk.load_config("legacy")
        record = json.loads((old / "composition.json").read_text())
        record.update(producerConfigSha256=legacy_sha, expectedVersion=legacy_config["expectedVersion"])
        (old / "composition.json").write_text(json.dumps(record, indent=2) + "\n")
        with self.assertRaisesRegex(sdk.Refusal, "composed under a different producer configuration"):
            sdk.admit_snapshot(old, self.config, self.config_sha)
        record.update(producerConfigSha256=self.config_sha)
        (old / "composition.json").write_text(json.dumps(record, indent=2) + "\n")
        with self.assertRaisesRegex(sdk.Refusal, "names a different expectedVersion"):
            sdk.admit_snapshot(old, self.config, self.config_sha)

    def test_built_version_must_be_the_root_version(self):
        template = sdk.git_bytes(sdk.WRAPPER / "Zano", "cat-file", "blob", "%s:src/version.h.in" % self.root).decode()
        build = self.tmp / "version-build"
        (build / "version").mkdir(parents=True)
        legacy_config, _sha = sdk.load_config("legacy")
        (build / "version/version.h").write_text(template.replace("@VERSION@", "1.0-g" + legacy_config["versionCommitLabel"]))
        with self.assertRaisesRegex(sdk.Refusal, "iphoneos built version 2.2.1.506\\[1.0-g299bf172"):
            sdk.check_built_version(build, self.config, "iphoneos")
        (build / "version/version.h").unlink()
        (build / "version/version.h").write_text(template.replace("@VERSION@", "1.0-g" + self.config["versionCommitLabel"]))
        self.assertEqual(sdk.check_built_version(build, self.config, "iphoneos"), self.config["expectedVersion"])

    def test_overlay_drift_is_refused(self):
        snapshot = self.fixture("plan-fixture")
        other = self.tmp / "other-wrapper"
        root = self.config["composition"]["projectOverlays"]["root"]
        for rel in self.config["composition"]["projectOverlays"]["paths"]:
            target = other / root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(str(sdk.WRAPPER / root / rel), str(target))
        target.write_bytes(target.read_bytes() + b"// drift\n")
        with self.assertRaisesRegex(sdk.Refusal, "Darwin overlay differs"):
            sdk.admit_snapshot(snapshot, self.config, self.config_sha, wrapper=other)

    def test_header_closure_is_owned_and_refuses_unresolved_paths(self):
        snapshot = self.fixture("plan-fixture")
        config = copy.deepcopy(self.config)
        config["headers"]["closurePaths"] = sorted(config["headers"]["closurePaths"] + ["wallet/not_in_the_core.h"])
        with self.assertRaisesRegex(sdk.Refusal, "resolves to no composed source"):
            sdk.source_header_plan(config, snapshot / "source")
        config = copy.deepcopy(self.config)
        config["headers"]["closurePaths"] = list(reversed(config["headers"]["closurePaths"]))
        with self.assertRaisesRegex(sdk.Refusal, "sorted list"):
            sdk.header_closure(config)


@unittest.skipUnless(LEGACY_CORE, "ZANO_LEGACY_CORE_GIT names no core repository with the legacy Apple composition")
class LegacyLibrarySdkProducer(ProducerFixture):
    profile = "legacy"

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.config, cls.config_sha = sdk.load_config("legacy")

    def test_plan_runs_from_this_wrapper_and_the_named_core(self):
        del OPENED[:]
        code, plan = run_plan(["plan", "--profile", "legacy", "--core-git", LEGACY_CORE,
                               "--scratch", str(self.tmp / "plan-main")])
        self.assertEqual(code, 0)
        self.assertEqual(plan["census"]["sha256"], "d019db972ab89dd60da61bac244f96f9afee703a1ba4034f70a4e7b185644b7e")
        self.assertEqual(plan["sourceCommit"], "fdee56b8f8d9d429848a49aa89d5d0278ba0839a")
        self.assertEqual(plan["expectedVersion"], self.config["expectedVersion"])
        self.assertEqual(plan["deltas"], 21)
        self.assertEqual(sum(plan["headerClosure"].values()), 287)
        self.assert_plan_reads_only_wrapper_and_scratch()

    def test_other_composition_commit_is_refused(self):
        ctx = sdk.admit_closure(self.config, self.config_sha, core=LEGACY_CORE)
        closure = dict(ctx["closure"], sourceCommit="98131bb6728ea79bb54e6c21a3a83a8bca27d686")
        with self.assertRaisesRegex(sdk.Refusal, "not the pinned Apple composition"):
            sdk.admit_closure(self.config, self.config_sha, closure=closure, core=LEGACY_CORE)

    def test_changed_closure_bytes_are_refused(self):
        closure = copy.deepcopy(sdk.admit_closure(self.config, self.config_sha, core=LEGACY_CORE)["closure"])
        next(r for r in closure["files"] if r["from"] == "submodule")["sha256"] = "0" * 64
        with self.assertRaisesRegex(sdk.Refusal, "does not resolve to its closure pin"):
            sdk.snapshot_from_closure(self.config, self.config_sha, str(self.tmp / "bytes"), closure=closure,
                                      core=LEGACY_CORE)

    def test_legacy_stage_is_refused_by_the_snapshot_recipe(self):
        snapshot = self.fixture("plan-fixture", "--core-git", LEGACY_CORE)
        config, sha = sdk.load_config("snapshot")
        with self.assertRaisesRegex(sdk.Refusal, "composed under a different producer configuration"):
            sdk.admit_snapshot(snapshot, config, sha)


if __name__ == "__main__":
    unittest.main()

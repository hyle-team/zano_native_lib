#!/usr/bin/env python3
"""Mutation checks of check_core_pin.py for both source profiles, against real core repositories.

Each case changes one profile fact, library file or the library gitlink and requires the checker to
refuse it; the unchanged profile must pass.
  legacy    ZANO_LEGACY_CORE_GIT must name a repository holding the original lineage
            (299bf172 .. e90a4e18). Without it the legacy cases are skipped, and the skip says so.
  snapshot  ZANO_SNAPSHOT_CORE_GIT (default: this library's Zano checkout) must hold the snapshot
            root. The library gitlink is read from the index, so the cases run before and after commit.
Usage: ZANO_LEGACY_CORE_GIT=CORE_REPO python3 -I mobile/test_check_core_pin.py -v
"""
import copy
import hashlib
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("check_core_pin", HERE / "check_core_pin.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
LEGACY_CORE = os.environ.get("ZANO_LEGACY_CORE_GIT")
SNAPSHOT_CORE = os.environ.get("ZANO_SNAPSHOT_CORE_GIT", str(HERE.parent / "Zano"))
HISTORICAL = ("299bf172e8428042919b48bfa1cedfcd9ede139a", "98131bb6728ea79bb54e6c21a3a83a8bca27d686",
              "fdee56b8f8d9d429848a49aa89d5d0278ba0839a", "e90a4e181fff7ff96ce03ddeda565d07cb5f75e8")


@unittest.skipUnless(LEGACY_CORE, "ZANO_LEGACY_CORE_GIT names no original-lineage core repository")
class CorePinChecks(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((HERE / "zano-mobile-sdk.json").read_text())
        self.core = checker.Git(LEGACY_CORE)
        self.tip = self.manifest["core"]["commit"]

    def refused(self, manifest, link=None):
        return checker.problems(manifest, self.tip if link is None else link, self.core)

    def test_pinned_manifest_passes(self):
        self.assertEqual(self.refused(self.manifest), [])

    def test_wrong_library_gitlink(self):
        self.assertTrue(any("gitlink" in p for p in self.refused(self.manifest, self.manifest["core"]["baseCommit"])))

    def test_changed_source_bytes_pin(self):
        m = copy.deepcopy(self.manifest)
        m["sourceMap"][0]["sha256"] = "0" * 64
        self.assertTrue(any("tip bytes differ" in p for p in self.refused(m)))

    def test_unlisted_change(self):
        m = copy.deepcopy(self.manifest)
        dropped = m["sourceMap"].pop()["path"]
        self.assertIn("unlisted change against the base: " + dropped, self.refused(m))

    def test_wrong_introducing_commit(self):
        m = copy.deepcopy(self.manifest)
        entry = next(e for e in m["sourceMap"] if e["finalRole"] == "host-unit-tests")
        entry["finalCommit"] = self.manifest["core"]["chain"][0]["commit"]
        self.assertTrue(any("not introduced" in p or "does not change" in p for p in self.refused(m)))

    def test_android_composition_must_exclude_project_overlays(self):
        m = copy.deepcopy(self.manifest)
        m["compositions"]["android-arm64-v8a-testnet"]["sourceCommit"] = self.tip
        self.assertTrue(any("android composition carries a project overlay" in p for p in self.refused(m)))

    def test_missing_delta_bytes(self):
        m = copy.deepcopy(self.manifest)
        m["appComposition"]["deltas"][0]["sha256"] = "f" * 64
        self.assertTrue(any("misses delta bytes" in p for p in self.refused(m)))

    def test_changed_submodule_pin(self):
        m = copy.deepcopy(self.manifest)
        first = sorted(m["submodulesUnchangedFromBase"])[0]
        m["submodulesUnchangedFromBase"][first] = "0" * 40
        self.assertIn("core submodule gitlinks differ from the base", self.refused(m))


class SnapshotProfileChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = json.loads((HERE / "zano-mobile-sdk-snapshot.json").read_text())
        cls.core = checker.Git(SNAPSHOT_CORE)
        cls.root = cls.profile["core"]["commit"]
        cls.link = checker.library_gitlink(checker.Git(HERE.parent), "Zano", None, True)

    def refused(self, profile, link=None, read_lib=checker.read_library_file, core=None):
        return checker.snapshot_problems(profile, self.root if link is None else link, core or self.core, read_lib)

    def mutated(self, change):
        p = copy.deepcopy(self.profile)
        change(p)
        return p

    @staticmethod
    def library_with(rel, data):
        return lambda path: data if path == rel else checker.read_library_file(path)

    def test_index_gitlink_is_the_root_and_the_profile_passes(self):
        self.assertEqual(self.link, self.root)
        self.assertEqual(self.refused(self.profile, self.link), [])

    def test_historical_objects_are_absent_and_never_needed(self):
        for commit in HISTORICAL:
            self.assertNotEqual(self.core.run("cat-file", "-e", commit, check=False).returncode, 0, commit)
        self.assertNotIn(self.root, HISTORICAL)
        for name in ("objects/info/alternates", "info/grafts", "shallow"):
            rel = self.core.run("rev-parse", "--git-path", name).stdout.decode().strip()
            self.assertFalse((Path(SNAPSHOT_CORE) / rel).exists(), name)
        self.assertEqual(self.core.run("for-each-ref", "refs/replace").stdout, b"")
        self.assertNotIn("GIT_ALTERNATE_OBJECT_DIRECTORIES", os.environ)
        self.assertEqual(self.refused(self.profile), [])

    def test_legacy_lineage_cannot_resolve_from_the_snapshot_core(self):
        legacy = json.loads((HERE / "zano-mobile-sdk.json").read_text())
        found = checker.problems(legacy, legacy["core"]["commit"], self.core)
        self.assertTrue(any("is unavailable" in p for p in found))

    def test_wrong_library_gitlink(self):
        self.assertTrue(any("gitlink" in p for p in self.refused(self.profile, HISTORICAL[3])))

    def test_missing_or_wrong_profile_declaration(self):
        for change in (lambda p: p.pop("sourceProfile"), lambda p: p.update(sourceProfile="legacy"),
                       lambda p: p.update(schema="zano-mobile-sdk-producer")):
            self.assertEqual(len(self.refused(self.mutated(change))), 1)
        legacy = json.loads((HERE / "zano-mobile-sdk.json").read_text())
        self.assertIn("declaration", self.refused(legacy)[0])

    def test_mixed_legacy_fields_are_refused(self):
        found = self.refused(self.mutated(lambda p: p["core"].update(chain=[], baseCommit=HISTORICAL[0])))
        self.assertTrue(any("legacy lineage fields: baseCommit, chain" in f for f in found))
        found = self.refused(self.mutated(lambda p: p["compositions"]["android-arm64-v8a-testnet"].update(
            currentArtifactEvidence={"publisherLockSha256": "0" * 64})))
        self.assertTrue(any("currentArtifactEvidence" in f for f in found))

    def test_historical_identifier_as_live_pin_is_refused(self):
        found = self.refused(self.mutated(lambda p: p["compositions"]["android-arm64-v8a-testnet"].update(
            sourceCommit=HISTORICAL[1])))
        self.assertIn("a live snapshot pin names a historical reference: " + HISTORICAL[1], found)
        self.assertIn("android composition is not the snapshot root", found)

    def test_unavailable_root_wrong_tree_and_parents(self):
        found = self.refused(self.mutated(lambda p: p["core"].update(commit="f" * 40)), link="f" * 40)
        self.assertTrue(any("is unavailable" in f for f in found))
        found = self.refused(self.mutated(lambda p: p["core"].update(tree="0" * 40)))
        self.assertTrue(any("not the declared" in f for f in found))
        found = self.refused(self.mutated(lambda p: p["core"].update(parents=[HISTORICAL[3]])))
        self.assertTrue(any("without parents" in f for f in found))
        with tempfile.TemporaryDirectory() as empty:
            checker.Git(empty).run("init", "-q")
            found = self.refused(self.profile, core=checker.Git(empty))
            self.assertTrue(any("is unavailable" in f for f in found))

    def test_changed_census_submodules_and_omitted_paths(self):
        for key, value in (("sha256", "0" * 64), ("blobCount", 1291), ("blobBytes", 1), ("gitlinkCount", 3)):
            found = self.refused(self.mutated(lambda p: p["sourceCensus"].update({key: value})))
            self.assertIn("the root tree differs from the declared source census", found, key)
        found = self.refused(self.mutated(lambda p: p["submodules"].update({"contrib/jwt-cpp": "0" * 40})))
        self.assertIn("core submodule gitlinks differ from the declared snapshot pins", found)
        found = self.refused(self.mutated(lambda p: p["submodules"].pop("src/gui/qt-daemon/layout")))
        self.assertIn("core submodule gitlinks differ from the declared snapshot pins", found)
        found = self.refused(self.mutated(lambda p: p["omittedPaths"].append("SOURCE-PROVENANCE.md")))
        self.assertIn("omitted path present at the root: SOURCE-PROVENANCE.md", found)

    def test_changed_composition_bytes(self):
        found = self.refused(self.mutated(lambda p: p["appComposition"]["deltas"][0].update(sha256="f" * 64)))
        self.assertTrue(any("misses composition bytes" in f for f in found))
        found = self.refused(self.mutated(lambda p: p["appComposition"]["projectOverlays"][0].update(size=1)))
        self.assertTrue(any("misses composition bytes" in f for f in found))
        found = self.refused(self.mutated(lambda p: p["core"]["provenanceNote"].update(sha256="0" * 64)))
        self.assertTrue(any("provenance note" in f for f in found))

    def test_version_mismatches_are_refused(self):
        legacy = json.loads((HERE / "zano-mobile-sdk.json").read_text())
        old = legacy["compositions"]["android-arm64-v8a-testnet"]["expectedVersion"]
        found = self.refused(self.mutated(lambda p: p["sdkVersion"].update(expectedVersion=old)))
        self.assertTrue(any("declared expected version" in f for f in found))
        found = self.refused(self.mutated(lambda p: p["compositions"]["apple-iphoneos-iphonesimulator-testnet"].update(
            expectedVersion=old)))
        self.assertTrue(any("apple composition expects" in f for f in found))
        found = self.refused(self.mutated(lambda p: p["sdkVersion"].update(commitLabel=HISTORICAL[0])))
        self.assertIn("the snapshot version label is not the root commit", found)
        found = self.refused(self.mutated(lambda p: p["sdkVersion"]["sourceVersion"].update(buildNumber=507)))
        self.assertIn("the root version facts are not the declared sourceVersion", found)

    def test_changed_library_inputs_and_scripts_are_refused(self):
        for rel, needle in (("mobile/android/inputs-snapshot.json", "Android inputs"),
                            ("mobile/ios/sdk-producer-snapshot.json", "iOS producer configuration"),
                            ("mobile/ios/closure-snapshot.json", "iOS closure"),
                            ("mobile/android/produce_android.py", "Android producer script"),
                            ("mobile/ios/sdk_producer.py", "iOS SDK producer")):
            data = checker.read_library_file(rel) + b"\n"
            found = self.refused(self.profile, read_lib=self.library_with(rel, data))
            self.assertTrue(any(needle in f and rel in f for f in found), rel)

    def test_closure_rows_must_resolve_and_give_the_census(self):
        rel = "mobile/ios/closure-snapshot.json"
        closure = json.loads(checker.read_library_file(rel))
        row = next(r for r in closure["files"] if r["from"] == "submodule")
        row["sha256"] = "0" * 64
        data = json.dumps(closure).encode()
        profile = self.mutated(lambda p: p["compositions"]["apple-iphoneos-iphonesimulator-testnet"]["closure"].update(
            sha256=hashlib.sha256(data).hexdigest()))
        found = self.refused(profile, read_lib=self.library_with(rel, data))
        self.assertIn("closure submodule path does not resolve to its pin: " + row["path"], found)
        self.assertIn("the closure rows do not give the declared census", found)

    def test_legacy_closure_is_not_a_snapshot_closure(self):
        legacy = "mobile/ios/closure.json"
        profile = self.mutated(lambda p: p["compositions"]["apple-iphoneos-iphonesimulator-testnet"].update(
            closure={"path": legacy, "sha256": hashlib.sha256(checker.read_library_file(legacy)).hexdigest()}))
        found = self.refused(profile)
        self.assertIn("the iOS closure is not the snapshot closure of the root and its census", found)

    def test_retained_legacy_files_must_stay_unchanged(self):
        rel = "mobile/android/inputs.json"
        found = self.refused(self.profile, read_lib=self.library_with(rel, checker.read_library_file(rel) + b" "))
        self.assertEqual(found, ["a retained legacy profile file changed: " + rel])

    def test_unmeasured_qualification_is_refused(self):
        found = self.refused(self.mutated(lambda p: p["qualification"].update(status="qualified")))
        self.assertIn("the snapshot profile claims a qualification no measurement has given", found)


if __name__ == "__main__":
    unittest.main()

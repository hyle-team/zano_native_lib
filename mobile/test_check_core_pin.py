#!/usr/bin/env python3
"""Mutation checks of check_core_pin.py against a real core repository.

Each case changes one manifest fact or the library gitlink and requires the checker to refuse it;
the unchanged manifest must pass.
Usage: ZANO_CORE_GIT=CORE_REPO python3 -I mobile/test_check_core_pin.py -v
"""
import copy
import importlib.util
import json
import os
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("check_core_pin", HERE / "check_core_pin.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
CORE = os.environ.get("ZANO_CORE_GIT", str(HERE.parent / "Zano"))


class CorePinChecks(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((HERE / "zano-mobile-sdk.json").read_text())
        self.core = checker.Git(CORE)
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


if __name__ == "__main__":
    unittest.main()

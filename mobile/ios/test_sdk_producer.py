#!/usr/bin/env python3
"""The library SDK producer evaluates from this wrapper alone.

Runs the real `plan` entry (closure -> composed snapshot -> admit_snapshot -> header plan) and records
every file Python opens: nothing outside this wrapper and the scratch directory may be read (no
consuming app, its SDK copies, its Android lock or its mount). Refusals cover the composition commit,
closure bytes, producer configuration, overlay drift and the header closure. Needs Zano and its
contrib/jwt-cpp and contrib/miniupnp submodules initialized. No build, toolchain or network.

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
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("zano_mobile_sdk_producer_under_test", str(HERE / "sdk_producer.py"))
sdk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sdk)
OPENED = []


def _audit(event, args):
    if event == "open" and args and isinstance(args[0], (str, bytes, os.PathLike)):
        OPENED.append(os.path.realpath(os.fsdecode(args[0])))


sys.addaudithook(_audit)


class LibrarySdkProducer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(os.path.realpath(tempfile.mkdtemp(prefix="zano-sdk-producer-")))
        cls.config, cls.config_sha = sdk.load_config()

    @classmethod
    def tearDownClass(cls):
        for d, _dirs, files in os.walk(str(cls.tmp)):
            os.chmod(d, 0o755)
            for f in files:
                os.chmod(os.path.join(d, f), 0o644)
        shutil.rmtree(str(cls.tmp))

    def test_plan_runs_from_this_wrapper_alone(self):
        del OPENED[:]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(sdk.main(["plan", "--scratch", str(self.tmp / "plan-main")]), 0)
        text = out.getvalue()
        plan = json.loads(text[text.index("{\n"):])  # progress lines precede the plan
        self.assertEqual(plan["census"]["sha256"], "d019db972ab89dd60da61bac244f96f9afee703a1ba4034f70a4e7b185644b7e")
        self.assertEqual(plan["deltas"], 21)
        self.assertEqual([o["path"] for o in plan["overlays"]],
                         ["Zano/" + p for p in self.config["composition"]["projectOverlays"]["paths"]])
        self.assertEqual(sum(plan["headerClosure"].values()), 287)
        self.assertEqual(plan["headerClosure"]["boost"], 2)
        wrapper, scratch = str(sdk.WRAPPER) + os.sep, str(self.tmp) + os.sep
        outside = sorted({p for p in OPENED if not (p.startswith(wrapper) or p.startswith(scratch))})
        self.assertEqual(outside, [], "the library plan read files outside the wrapper")

    def test_module_names_no_app_path(self):
        source = (HERE / "sdk_producer.py").read_text(encoding="utf-8")
        for needle in ("native/zano", "zano-core", "artifacts.testnet-lifecycle", "source-overlay", "PROJECT ="):
            self.assertNotIn(needle, source)
        # Resolution keys of the configuration are wrapper-owned (versionOrigin keeps historical evidence names).
        self.assertEqual(self.config["composition"]["projectOverlays"]["root"], "Zano")
        self.assertNotIn("closureFrom", self.config["headers"])
        self.assertEqual(len(self.config["headers"]["closurePaths"]), 287)
        self.assertTrue(all(hasattr(sdk, name) for name in sdk.INTERFACE))

    def test_other_composition_commit_is_refused(self):
        ctx = sdk.admit_closure(self.config, self.config_sha)
        closure = dict(ctx["closure"], sourceCommit="98131bb6728ea79bb54e6c21a3a83a8bca27d686")
        with self.assertRaisesRegex(sdk.Refusal, "not the pinned Apple composition"):
            sdk.admit_closure(self.config, self.config_sha, closure=closure)

    def test_other_configuration_is_refused(self):
        with self.assertRaisesRegex(sdk.Refusal, "another producer configuration"):
            sdk.admit_closure(self.config, "0" * 64)

    def test_changed_closure_bytes_are_refused(self):
        closure = copy.deepcopy(sdk.admit_closure(self.config, self.config_sha)["closure"])
        next(r for r in closure["files"] if r["from"] == "submodule")["sha256"] = "0" * 64
        with self.assertRaisesRegex(sdk.Refusal, "does not resolve to its closure pin"):
            sdk.snapshot_from_closure(self.config, self.config_sha, str(self.tmp / "bytes"), closure=closure)

    def test_overlay_drift_is_refused(self):
        snapshot = self.tmp / "plan-fixture" / "snapshot"
        if not snapshot.exists():
            with contextlib.redirect_stdout(io.StringIO()):
                sdk.main(["plan", "--scratch", str(self.tmp / "plan-fixture")])
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
        snapshot = self.tmp / "plan-fixture" / "snapshot"
        if not snapshot.exists():
            with contextlib.redirect_stdout(io.StringIO()):
                sdk.main(["plan", "--scratch", str(self.tmp / "plan-fixture")])
        config = copy.deepcopy(self.config)
        config["headers"]["closurePaths"] = sorted(config["headers"]["closurePaths"] + ["wallet/not_in_the_core.h"])
        with self.assertRaisesRegex(sdk.Refusal, "resolves to no composed source"):
            sdk.source_header_plan(config, snapshot / "source")
        config = copy.deepcopy(self.config)
        config["headers"]["closurePaths"] = list(reversed(config["headers"]["closurePaths"]))
        with self.assertRaisesRegex(sdk.Refusal, "sorted list"):
            sdk.header_closure(config)


if __name__ == "__main__":
    unittest.main()

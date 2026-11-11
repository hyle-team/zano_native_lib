#!/usr/bin/env python3
"""Dry checks of produce_android.py against real git objects (no toolchain, no build, no LFS fetch).

Usage: ZANO_CORE_GIT=CORE_REPO python3 -I mobile/android/test_produce_android.py -v
CORE_REPO must hold the declared composition commit (for example the core branch checkout).
"""
import copy
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("produce_android", HERE / "produce_android.py")
recipe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipe)
CORE = os.environ.get("ZANO_CORE_GIT", str(HERE.parents[1] / "Zano"))


class AndroidRecipeDryChecks(unittest.TestCase):
    def setUp(self):
        self.manifest, self.spec, self.inputs = recipe.load()

    def test_every_non_built_input_resolves_to_its_pin(self):
        rows = recipe.pinned_inputs(CORE, self.inputs)
        self.assertEqual(len(rows), len(self.inputs["headers"]) + len(self.inputs["dependencies"]))
        self.assertEqual(sum(isinstance(v, tuple) for _, v in rows), 14)
        outputs = {o for o, _ in rows}
        self.assertFalse(outputs & set(self.inputs["builtOutputs"]), "built outputs carry no pin")

    def test_source_must_be_the_declared_composition(self):
        head = recipe.git(CORE, "rev-parse", "HEAD").decode().strip()
        if head == self.spec["sourceCommit"]:
            self.skipTest("core checkout is at the declared commit")
        with self.assertRaisesRegex(SystemExit, "not the declared composition"):
            recipe.check_source(CORE, self.spec)

    def test_changed_header_pin_is_refused(self):
        inputs = copy.deepcopy(self.inputs)
        inputs["headers"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(SystemExit, "header differs"):
            recipe.pinned_inputs(CORE, inputs)

    def test_moved_lfs_pointer_is_refused(self):
        inputs = copy.deepcopy(self.inputs)
        dep = next(d for d in inputs["dependencies"] if "pointerBlob" in d)
        dep["pointerBlob"] = "0" * 40
        with self.assertRaisesRegex(SystemExit, "LFS pointer moved"):
            recipe.pinned_inputs(CORE, inputs)

    def test_wrong_ndk_is_refused(self):
        with tempfile.TemporaryDirectory() as ndk:
            Path(ndk, "source.properties").write_text("Pkg.Revision = 26.3.11579264\n")
            with self.assertRaisesRegex(SystemExit, "NDK must be 27.1.12297006"):
                recipe.toolchain(self.spec, ndk, "cmake")

    def test_existing_output_is_refused_before_any_work(self):
        with tempfile.TemporaryDirectory() as out:
            with self.assertRaisesRegex(SystemExit, "--out must not exist"):
                recipe.main(["build", "--source", CORE, "--ndk", "/nonexistent", "--cmake", "cmake", "--out", out])

    def test_configure_identity(self):
        args = recipe.configure_args(self.spec, Path("/s"), Path("/b"), Path("/d"), "/ndk")
        for flag in ("-DCMAKE_SYSTEM_VERSION=24", "-DCMAKE_ANDROID_ARCH_ABI=arm64-v8a",
                     "-DCMAKE_ANDROID_STL_TYPE=c++_shared", "-DCMAKE_CXX_STANDARD=17", "-DTESTNET=ON",
                     "-DBUILD_TESTS=OFF", "-DDISABLE_TOR=ON", "-DGIT=OFF", "-DCOMMIT_ID_IN_VERSION=ON",
                     "-DCOMMIT=299bf172e8428042919b48bfa1cedfcd9ede139a-native-snapshot-compat-v1"):
            self.assertIn(flag, args)
        self.assertEqual(recipe.TARGETS, ("wallet", "currency_core", "crypto", "common", "zlibstatic"))


if __name__ == "__main__":
    unittest.main()

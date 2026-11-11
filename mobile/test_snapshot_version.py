#!/usr/bin/env python3
"""Host CMake proof of the snapshot SDK version identity (configure only: no compiler, no dependencies).

Reads CMakeLists.txt and src/version.h.in at the snapshot root from the core checkout and copies three
pieces of CMakeLists.txt verbatim into a scratch project: its cmake_minimum_required line, its
set(VERSION ...) line and its version block (set(COMMIT_ID_IN_VERSION ...) through the matching
endif()). The one added line is project(... NONE), which keeps CMake from probing a compiler. Host
CMake then configures that project with the identity options (REFS, GIT, COMMIT_ID_IN_VERSION, COMMIT,
TESTNET) the Android and iOS producers actually plan, and both producers' own checkers read the
generated version/version.h:
  * the snapshot options give the profile's expected version, and both checkers accept it;
  * the legacy producers' label goes through the same production branch, and the snapshot
    checkers reject the header it generates;
  * TESTNET does not reach the version string on this route (same header with TESTNET=OFF).
The version formula is never restated here, so a change to the root's version logic fails the test.

Needs host cmake >= 3.16 with its default generator, and ZANO_SNAPSHOT_CORE_GIT (default: this
library's Zano checkout) holding the snapshot root.
Usage: python3 -I mobile/test_snapshot_version.py -v
"""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
LIB = HERE.parent
SNAPSHOT_CORE = os.environ.get("ZANO_SNAPSHOT_CORE_GIT", str(LIB / "Zano"))
IDENTITY = ("REFS", "GIT", "COMMIT_ID_IN_VERSION", "COMMIT", "TESTNET")


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


android = load("produce_android_under_version_proof", HERE / "android" / "produce_android.py")
ios = load("sdk_producer_under_version_proof", HERE / "ios" / "sdk_producer.py")


def root_blob(root, path):
    return subprocess.run(["git", "-C", SNAPSHOT_CORE, "cat-file", "blob", "%s:%s" % (root, path)],
                          stdout=subprocess.PIPE, check=True).stdout.decode("utf-8")


def production_version_project(cmakelists):
    """The proof CMakeLists.txt: the root's own lines and version block, plus project(... NONE)."""
    lines = cmakelists.splitlines(keepends=True)
    minimum = [l for l in lines if l.startswith("cmake_minimum_required(")]
    version = [l for l in lines if l.startswith('set(VERSION "')]
    start = [i for i, l in enumerate(lines) if l.startswith("set(COMMIT_ID_IN_VERSION ")]
    if len(minimum) != 1 or len(version) != 1 or len(start) != 1:
        raise AssertionError("the root CMakeLists.txt no longer has one minimum, VERSION and COMMIT_ID_IN_VERSION line")
    depth, end = 0, None
    for i in range(start[0], len(lines)):
        word = lines[i].strip().lower()
        if re.match(r"if\s*\(", word):
            depth += 1
        elif re.match(r"endif\s*\(", word):
            depth -= 1
            if depth == 0:
                end = i
                break
    if end is None:
        raise AssertionError("the root version block has no closing endif()")
    block = "".join(lines[start[0]:end + 1])
    return minimum[0] + "project(zano_snapshot_version_proof NONE)\n" + version[0] + block, block


def identity_options(argv):
    found = {}
    for arg in argv:
        if arg.startswith("-D"):
            key, _sep, value = arg[2:].partition("=")
            if key in IDENTITY:
                found[key] = value
    return found


class SnapshotVersionConfigureProof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cmake = shutil.which("cmake")
        if cls.cmake is None:
            raise AssertionError("host cmake is required for the snapshot version proof")
        cls.tmp = Path(tempfile.mkdtemp(prefix="zano-snapshot-version-"))
        cls.profile = json.loads((HERE / "zano-mobile-sdk-snapshot.json").read_text())
        cls.root = cls.profile["core"]["commit"]
        cls.project, cls.block = production_version_project(root_blob(cls.root, "CMakeLists.txt"))
        source = cls.tmp / "source"
        (source / "src").mkdir(parents=True)
        (source / "CMakeLists.txt").write_text(cls.project)
        (source / "src" / "version.h.in").write_text(root_blob(cls.root, "src/version.h.in"))
        cls.source = source
        version = subprocess.run([cls.cmake, "--version"], stdout=subprocess.PIPE, check=True).stdout.decode()
        print("[version-proof] host %s" % version.splitlines()[0], file=sys.stderr)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(cls.tmp))

    def planned(self, profile):
        """Identity options of both producers for a profile; they must agree."""
        _manifest, spec, _inputs = android.load(profile)
        config, _sha = ios.load_config(profile)
        unused = Path("/unused")
        planned_android = identity_options(android.configure_args(spec, unused, unused, unused, "/unused"))
        planned_ios = identity_options(ios.configure_argv("cmake", config, "iphoneos", config["sdks"]["iphoneos"],
                                                          unused, unused, unused, config["versionCommitLabel"]))
        self.assertEqual(sorted(planned_android), sorted(IDENTITY), "Android plans every identity option")
        self.assertEqual(planned_android, planned_ios, "both producers plan the same identity options")
        return spec, config, planned_android

    def configure(self, name, options):
        build = self.tmp / name
        env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": os.environ.get("HOME", str(self.tmp)),
               "LANG": "C", "LC_ALL": "C"}
        argv = [self.cmake, "-S", str(self.source), "-B", str(build)] + ["-D%s=%s" % kv for kv in sorted(options.items())]
        proc = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, timeout=300)
        self.assertEqual(proc.returncode, 0, proc.stdout.decode(errors="replace")[-2000:])
        return build

    def test_production_commit_route_gives_the_snapshot_version(self):
        self.assertIn("elseif(DEFINED COMMIT)", self.block)
        self.assertIn('configure_file("src/version.h.in" "version/version.h")', self.block)
        spec, config, options = self.planned("snapshot")
        self.assertEqual(options, {"REFS": "", "GIT": "OFF", "COMMIT_ID_IN_VERSION": "ON", "COMMIT": self.root,
                                   "TESTNET": "ON"})
        build = self.configure("snapshot", options)
        expected = self.profile["sdkVersion"]["expectedVersion"]
        self.assertEqual(android.built_version(build), expected)
        self.assertEqual(ios.built_version(build), expected)
        android.check_version_header(build, spec)
        self.assertEqual(ios.check_built_version(build, config, "iphoneos"), expected)
        self.assertEqual(spec["expectedVersion"], expected)
        self.assertEqual(config["expectedVersion"], expected)

        flipped = self.configure("snapshot-testnet-off", dict(options, TESTNET="OFF"))
        self.assertEqual((flipped / "version/version.h").read_bytes(), (build / "version/version.h").read_bytes(),
                         "TESTNET reaches the version string")

        _legacy_spec, legacy_config, legacy_options = self.planned("legacy")
        self.assertEqual(legacy_options, dict(options, COMMIT=legacy_config["versionCommitLabel"]))
        old = self.configure("legacy-label", legacy_options)
        self.assertNotEqual(android.built_version(old), expected)
        with self.assertRaisesRegex(SystemExit, "version.h carries"):
            android.check_version_header(old, spec)
        with self.assertRaisesRegex(ios.Refusal, "built version"):
            ios.check_built_version(old, config, "iphoneos")


if __name__ == "__main__":
    unittest.main()

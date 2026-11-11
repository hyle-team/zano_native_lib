#!/usr/bin/env python3
"""Clean Android producer of the Zano mobile SDK composition (TESTNET/103, arm64-v8a, API 24).

Builds wallet, currency_core, crypto, common and zlibstatic from the core checkout at exactly the
declared composition commit, and writes the consumer layout the app's verified lock admits:

  _install_android/arm64-v8a/lib/lib{common,crypto,currency_core,wallet,z,backtrace}.a
  _install_android/arm64-v8a/VERSION        expectedVersion bytes, no terminator
  _install_android/include/<path>          the pinned header set (inputs.json)
  _libs_android/{boost,openssl}/arm64-v8a/lib/*.a and LICENSE
  inventory.json                           measured path/size/sha256 of every written file

Every non-built input is pinned in the profile's inputs file to a public git identity: the core
commit, a zano_native_lib main commit, or the Git LFS oid of a committed dependency archive
(materialized with `git lfs smudge` and re-hashed). Toolchain identity is fixed by the profile
manifest (NDK 27.1.12297006, CMake 3.22.1, c++_shared, API 24). A fresh --out is required; nothing is
reused.

Source profiles (--profile is required)
  legacy    mobile/zano-mobile-sdk.json + inputs.json: the retained original lineage composition
            (core 98131bb6, observed snapshot-compat-v1 version label). Needs a core checkout that
            holds that commit.
  snapshot  mobile/zano-mobile-sdk-snapshot.json + inputs-snapshot.json: the maintained snapshot
            root. The core checkout must be at the root; the version label is the root commit. The
            inputs file and this script must be the exact bytes the snapshot profile pins.

Commands
  plan   --profile P --source ZANO_CHECKOUT                 dry checks only (no toolchain, nothing written)
  build  --profile P --source ZANO_CHECKOUT --ndk NDK_ROOT --cmake CMAKE --out NEW_DIR [--jobs N]

This recipe is authored from the composition's declared identities. Until an actual execution is
measured and its inventory adopted as a new app lock, it is not evidence of any shipped artifact.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIB = HERE.parents[1]
SCRIPT = Path(__file__).resolve()
PROFILES = {"legacy": (LIB / "mobile" / "zano-mobile-sdk.json", HERE / "inputs.json"),
            "snapshot": (LIB / "mobile" / "zano-mobile-sdk-snapshot.json", HERE / "inputs-snapshot.json")}
SNAPSHOT_PROFILE = "maintained-snapshot-v1"
COMPOSITION = "android-arm64-v8a-testnet"
TARGETS = ("wallet", "currency_core", "crypto", "common", "zlibstatic")
ARCHIVES = {"src/libcommon.a": "libcommon.a", "src/libcrypto.a": "libcrypto.a",
            "src/libcurrency_core.a": "libcurrency_core.a", "src/libwallet.a": "libwallet.a",
            "contrib/zlib/libz.a": "libz.a"}
REQUIRED_SUBMODULES = ("contrib/jwt-cpp", "contrib/miniupnp")


def refuse(message):
    raise SystemExit("produce_android: " + message)


def git(repo, *args, data=None):
    proc = subprocess.run(["git", "-C", str(repo), *args], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        refuse("git %s failed in %s: %s" % (args[0], repo, proc.stderr.decode(errors="replace").strip()))
    return proc.stdout


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def load(profile=None):
    if profile not in PROFILES:
        refuse("an explicit source profile is required (legacy or snapshot), not %r" % (profile,))
    manifest_path, inputs_path = PROFILES[profile]
    inputs_bytes = inputs_path.read_bytes()
    manifest, inputs = json.loads(manifest_path.read_text()), json.loads(inputs_bytes)
    spec = admit(profile, manifest, inputs, sha256(inputs_bytes), sha256(SCRIPT.read_bytes()))
    return manifest, spec, inputs


def version_label(spec):
    """The CMake COMMIT label carried by expectedVersion (<project>.<build>[1.0-g<label>])."""
    return spec["expectedVersion"].split("[1.0-g", 1)[1][:-1]


def admit(profile, manifest, inputs, inputs_sha, script_sha):
    """The composition spec of the profile; refuses mixed, missing or inconsistent profile files."""
    spec = manifest["compositions"][COMPOSITION]
    if inputs.get("schema") != "zano-mobile-android-producer-inputs" or inputs.get("composition") != COMPOSITION:
        refuse("inputs.json is not the Android producer input set")
    if inputs["sourceCommit"] != spec["sourceCommit"]:
        refuse("inputs.json and the manifest name different source commits")
    if profile == "legacy":
        if manifest.get("schema") != "zano-mobile-sdk-producer" or "sourceProfile" in manifest or "sourceProfile" in inputs:
            refuse("the legacy profile is the retained lineage manifest with its own inputs")
        return spec
    if manifest.get("schema") != "zano-mobile-sdk-snapshot-profile" or manifest.get("sourceProfile") != SNAPSHOT_PROFILE \
            or inputs.get("sourceProfile") != SNAPSHOT_PROFILE:
        refuse("the snapshot profile needs the snapshot manifest and the snapshot inputs")
    root, version = manifest["core"]["commit"], manifest["sdkVersion"]
    if spec["sourceCommit"] != root:
        refuse("the snapshot Android composition is not the snapshot root %s" % root)
    if spec["expectedVersion"] != version["expectedVersion"] or version["commitLabel"] != root or version_label(spec) != root:
        refuse("the snapshot Android version is not the root-labelled expected version")
    if "currentArtifactEvidence" in spec or manifest.get("qualification", {}).get("status") != "unqualified":
        refuse("the snapshot profile carries artifact evidence or a qualification it has not measured")
    recipe = spec["producerRecipe"]
    if recipe["inputsSha256"] != inputs_sha:
        refuse("the snapshot inputs are not the bytes the profile pins")
    if recipe["scriptSha256"] != script_sha:
        refuse("produce_android.py is not the script the snapshot profile pins")
    return spec


def check_source(source, spec):
    head = git(source, "rev-parse", "HEAD").decode().strip()
    if head != spec["sourceCommit"]:
        refuse("the core checkout is at %s, not the declared composition %s" % (head, spec["sourceCommit"]))
    if git(source, "status", "--porcelain", "--untracked-files=no", "--ignore-submodules=none").strip():
        refuse("the core checkout has tracked modifications")
    for path in REQUIRED_SUBMODULES:
        pinned = git(source, "ls-tree", "HEAD", "--", path).decode().split()[2]
        if not (Path(source) / path / ".git").exists() or git(Path(source) / path, "rev-parse", "HEAD").decode().strip() != pinned:
            refuse("core submodule %s must be initialized at its pinned %s" % (path, pinned))


def pinned_inputs(source, inputs):
    """[(output path, bytes)] of every non-built file, each checked against its pin."""
    rows = []
    for h in inputs["headers"]:
        repo, rev = (source, inputs["sourceCommit"]) if h["from"] == "core" else (LIB, h["commit"])
        data = git(repo, "cat-file", "blob", "%s:%s" % (rev, h["path"]))
        if sha256(data) != h["sha256"] or len(data) != h["size"]:
            refuse("header differs from its pin: " + h["include"])
        rows.append(("_install_android/include/" + h["include"], data))
    for d in inputs["dependencies"]:
        if "pointerBlob" in d:
            pointer = git(LIB, "cat-file", "blob", "%s:%s" % (d["commit"], d["path"]))
            if git(LIB, "rev-parse", "%s:%s" % (d["commit"], d["path"])).decode().strip() != d["pointerBlob"]:
                refuse("LFS pointer moved: " + d["output"])
            rows.append((d["output"], ("lfs", pointer, d)))
        else:
            data = git(LIB, "cat-file", "blob", "%s:%s" % (d["commit"], d["path"]))
            if sha256(data) != d["sha256"] or len(data) != d["size"]:
                refuse("dependency differs from its pin: " + d["output"])
            rows.append((d["output"], data))
    for name, t in inputs["buildTrees"].items():
        if git(LIB, "rev-parse", "%s:%s" % (t["commit"], t["path"])).decode().strip() != t["tree"]:
            refuse("build tree moved: " + name)
    return rows


def materialize(value):
    if not (isinstance(value, tuple) and value[0] == "lfs"):
        return value
    _, pointer, d = value
    data = git(LIB, "lfs", "smudge", "--", d["path"], data=pointer)
    if sha256(data) != d["lfsSha256"] or len(data) != d["size"]:
        refuse("LFS object differs from its pinned oid: " + d["output"])
    return data


def toolchain(spec, ndk, cmake):
    expected = spec["toolchain"]
    props = (Path(ndk) / "source.properties").read_text()
    match = re.search(r"^Pkg\.Revision\s*=\s*([0-9.]+)\s*$", props, re.M)
    if not match or match.group(1) != expected["ndk"]:
        refuse("NDK must be %s" % expected["ndk"])
    version = subprocess.run([cmake, "--version"], stdout=subprocess.PIPE, text=True).stdout.split()
    if len(version) < 3 or version[2] != expected["cmake"]:
        refuse("CMake must be %s" % expected["cmake"])
    if expected["stl"] != "c++_shared" or expected["androidApi"] != 24:
        refuse("unexpected declared toolchain")


def write(root, rel, data):
    target = root / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    with open(target, "xb") as handle:
        handle.write(data)


def configure_args(spec, source, build, deps, ndk):
    label = version_label(spec)
    return ["-S", str(source), "-B", str(build), "-G", "Unix Makefiles", "-Wno-dev",
            "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_SYSTEM_NAME=Android", "-DCMAKE_SYSTEM_VERSION=24",
            "-DCMAKE_ANDROID_ARCH_ABI=arm64-v8a", "-DCMAKE_ANDROID_NDK=%s" % ndk,
            "-DCMAKE_ANDROID_STL_TYPE=c++_shared", "-DCMAKE_CXX_STANDARD=17",
            "-DTESTNET=ON", "-DBUILD_TESTS=OFF", "-DBUILD_GUI=OFF", "-DUSE_PCH=OFF", "-DCAKEWALLET=OFF",
            "-DUSE_BITCOIN_SECP256K1_FOR_ECDSA=OFF", "-DDISABLE_TOR=ON", "-DBUILD_SHARED_LIBS=OFF",
            "-DCMAKE_POSITION_INDEPENDENT_CODE=ON", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
            "-DREFS=", "-DGIT=OFF", "-DCOMMIT_ID_IN_VERSION=ON", "-DCOMMIT=%s" % label,
            "-DBoost_VERSION=Boost 1.84.0", "-DBoost_LIBRARY_DIRS=%s/boost/arm64-v8a/lib" % deps,
            "-DBoost_INCLUDE_DIRS=%s/boost/include" % deps,
            "-DOPENSSL_INCLUDE_DIR=%s/openssl/arm64-v8a/include" % deps,
            "-DOPENSSL_CRYPTO_LIBRARY=%s/openssl/arm64-v8a/lib/libcrypto.a" % deps,
            "-DOPENSSL_SSL_LIBRARY=%s/openssl/arm64-v8a/lib/libssl.a" % deps,
            "-DBACKTRACE_ROOT=%s/libbacktrace" % deps]


def built_version(build_dir):
    """PROJECT_VERSION_LONG of the generated version.h, assembled from its defines (the header only
    concatenates them with macros, so the long version never appears there as one literal)."""
    text = (build_dir / "version" / "version.h").read_text()
    values = dict(re.findall(r'^#define\s+(\w+)\s+"([^"]*)"', text, re.M))
    number = re.search(r"^#define\s+PROJECT_VERSION_BUILD_NO\s+(\d+)", text, re.M)
    if not number or not {"PROJECT_MAJOR_VERSION", "PROJECT_MINOR_VERSION", "PROJECT_REVISION", "BUILD_COMMIT_ID"} <= set(values):
        refuse("the generated version.h has no build identity")
    return "%s.%s.%s.%s[%s]" % (values["PROJECT_MAJOR_VERSION"], values["PROJECT_MINOR_VERSION"],
                                values["PROJECT_REVISION"], number.group(1), values["BUILD_COMMIT_ID"])


def check_version_header(build_dir, spec):
    version = built_version(build_dir)
    if version != spec["expectedVersion"]:
        refuse("the generated version.h carries %s, not %s" % (version, spec["expectedVersion"]))


def build(args):
    manifest, spec, inputs = load(args.profile)
    source = Path(args.source).resolve()
    out = Path(args.out)
    if out.exists():
        refuse("--out must not exist")
    check_source(source, spec)
    rows = pinned_inputs(source, inputs)
    toolchain(spec, args.ndk, args.cmake)
    scratch = out.parent / (out.name + ".work")
    if scratch.exists():
        refuse("a previous work directory exists: %s" % scratch)
    deps, build_dir, stage = scratch / "deps", scratch / "build", scratch / "stage"
    for name, t in inputs["buildTrees"].items():
        target = deps / name
        target.mkdir(parents=True)
        archive = git(LIB, "archive", "--format=tar", t["tree"])
        subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    for output, value in rows:
        data = materialize(value)
        write(stage, output, data)
        if output.startswith("_libs_android/"):
            write(deps, output[len("_libs_android/"):], data)
        if output.endswith("libbacktrace.a"):
            write(deps, "libbacktrace/arm64-v8a/lib/libbacktrace.a", data)
    subprocess.run([args.cmake, *configure_args(spec, source, build_dir, deps, args.ndk)], check=True)
    subprocess.run([args.cmake, "--build", str(build_dir), "--target", *TARGETS, "--", "-j%d" % args.jobs], check=True)
    check_version_header(build_dir, spec)
    for built, name in ARCHIVES.items():
        write(stage, "_install_android/arm64-v8a/lib/" + name, (build_dir / built).read_bytes())
    write(stage, "_install_android/arm64-v8a/VERSION", spec["expectedVersion"].encode("ascii"))
    inventory = []
    for p in sorted(stage.rglob("*")):
        if p.is_file():
            data = p.read_bytes()
            inventory.append({"path": p.relative_to(stage).as_posix(), "size": len(data), "sha256": sha256(data)})
    record = {"composition": COMPOSITION, "sourceCommit": spec["sourceCommit"],
              "expectedVersion": spec["expectedVersion"], "files": inventory}
    if args.profile == "snapshot":
        record = dict({"sourceProfile": SNAPSHOT_PROFILE}, **record)
    write(stage, "inventory.json", (json.dumps(record, indent=1) + "\n").encode())
    os.rename(stage, out)
    shutil.rmtree(scratch)
    print(json.dumps({"out": str(out), "files": len(inventory)}))


def plan(args):
    _, spec, inputs = load(args.profile)
    source = Path(args.source).resolve()
    check_source(source, spec)
    rows = pinned_inputs(source, inputs)
    print(json.dumps({"profile": args.profile, "composition": COMPOSITION, "sourceCommit": spec["sourceCommit"],
                      "expectedVersion": spec["expectedVersion"], "toolchain": spec["toolchain"],
                      "pinnedInputs": len(rows), "lfsObjects": sum(isinstance(v, tuple) for _, v in rows),
                      "builtOutputs": inputs["builtOutputs"], "targets": TARGETS}, indent=1))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("plan")
    p.add_argument("--profile", required=True, choices=sorted(PROFILES))
    p.add_argument("--source", required=True)
    b = sub.add_parser("build")
    b.add_argument("--profile", required=True, choices=sorted(PROFILES))
    b.add_argument("--source", required=True)
    b.add_argument("--ndk", required=True)
    b.add_argument("--cmake", required=True)
    b.add_argument("--out", required=True)
    b.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args(argv)
    (plan if args.command == "plan" else build)(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())

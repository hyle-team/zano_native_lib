#!/usr/bin/env python3
"""Verify the mobile SDK producer pins (zano-mobile-sdk.json) against git objects.

Checks, without building or checking anything out:
  * this repository's Zano gitlink (at --rev) is the manifest core commit;
  * the core chain is exactly base -> each listed commit (first parent) -> tip;
  * every source-map path holds its pinned sha256/size at the tip and got those
    final bytes in its listed commit, and no other path differs from the base;
  * the core submodule gitlinks are unchanged from the base;
  * the Android composition commit holds every app composition delta and none of
    the project overlays; the Apple composition commit holds both;
  * no forbidden path exists at the tip.

Usage: python3 -I mobile/check_core_pin.py --core-git CORE_REPO [--rev REV]
CORE_REPO is any git repository holding the core commits (for example the
initialized Zano submodule, or a local clone of the core branch).
Standard library only. Exit 0 when every check passes; findings are printed as JSON.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIB = HERE.parent
MANIFEST = HERE / "zano-mobile-sdk.json"


class Git:
    def __init__(self, repo):
        self.repo = str(repo)

    def run(self, *args, check=True):
        proc = subprocess.run(["git", "-C", self.repo, *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if check and proc.returncode != 0:
            raise LookupError(proc.stderr.decode(errors="replace").strip() or "git %s failed" % args[0])
        return proc

    def blob(self, rev, path):
        proc = self.run("cat-file", "blob", "%s:%s" % (rev, path), check=False)
        return proc.stdout if proc.returncode == 0 else None

    def parent(self, rev):
        return self.run("rev-parse", rev + "^").stdout.decode().strip()

    def changed(self, a, b):
        return {p for p in self.run("diff", "--name-only", "-z", a, b).stdout.decode().split("\0") if p}

    def gitlinks(self, rev):
        links = {}
        for line in self.run("ls-tree", "-r", rev).stdout.decode().splitlines():
            meta, path = line.split("\t", 1)
            mode, kind, obj = meta.split()
            if kind == "commit":
                links[path] = obj
        return links


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def problems(manifest, lib_gitlink, core):
    found = []
    pin = manifest["core"]
    base, tip = pin["baseCommit"], pin["commit"]
    if lib_gitlink != tip:
        found.append("library Zano gitlink %s is not the manifest core commit %s" % (lib_gitlink, tip))
    chain = [c["commit"] for c in pin["chain"]]
    if not chain or chain[-1] != tip:
        found.append("the core chain does not end at the manifest core commit")
    previous = base
    for commit in chain:
        try:
            parent = core.parent(commit)
        except LookupError as error:
            found.append("core commit %s is unavailable: %s" % (commit, error))
            return found
        if parent != previous:
            found.append("core commit %s has parent %s, expected %s" % (commit, parent, previous))
        previous = commit
    entries = {e["path"]: e for e in manifest["sourceMap"]}
    for path, entry in entries.items():
        data = core.blob(tip, path)
        if data is None or sha256(data) != entry["sha256"] or len(data) != entry["size"]:
            found.append("tip bytes differ from the source map: " + path)
        final = entry["finalCommit"]
        if final not in chain:
            found.append("source map names a commit outside the chain: " + path)
            continue
        before = core.parent(final)
        at_final, at_before = core.blob(final, path), core.blob(before, path)
        if at_final is None or sha256(at_final) != entry["sha256"]:
            found.append("final bytes are not introduced by %s: %s" % (final[:12], path))
        elif at_before is not None and sha256(at_before) == entry["sha256"]:
            found.append("%s does not change %s" % (final[:12], path))
    actual = core.changed(base, tip)
    for path in sorted(actual - set(entries)):
        found.append("unlisted change against the base: " + path)
    for path in sorted(set(entries) - actual):
        found.append("source map lists an unchanged path: " + path)
    expected_links = manifest["submodulesUnchangedFromBase"]
    if core.gitlinks(tip) != expected_links or core.gitlinks(base) != expected_links:
        found.append("core submodule gitlinks differ from the base")
    app = manifest["appComposition"]
    android = manifest["compositions"]["android-arm64-v8a-testnet"]["sourceCommit"]
    apple = manifest["compositions"]["apple-iphoneos-iphonesimulator-testnet"]["sourceCommit"]
    for label, commit in (("android", android), ("apple", apple)):
        if commit not in chain:
            found.append("%s composition commit is outside the chain" % label)
            continue
        for delta in app["deltas"]:
            data = core.blob(commit, delta["path"])
            if data is None or sha256(data) != delta["sha256"]:
                found.append("%s composition misses delta bytes: %s" % (label, delta["path"]))
    for path in app["projectOverlays"]:
        at_base, at_android, at_apple, at_tip = (core.blob(r, path) for r in (base, android, apple, tip))
        if at_android != at_base:
            found.append("android composition carries a project overlay: " + path)
        if at_apple is None or at_apple != at_tip or at_apple == at_base:
            found.append("apple composition lacks its project overlay bytes: " + path)
    for forbidden in app["forbiddenPaths"]:
        if core.blob(tip, forbidden["path"]) is not None:
            found.append("forbidden path present at the tip: " + forbidden["path"])
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--core-git", required=True)
    parser.add_argument("--rev", default="HEAD")
    args = parser.parse_args(argv)
    manifest = json.loads(MANIFEST.read_text())
    lib = Git(LIB)
    link = lib.gitlinks(args.rev).get(manifest["core"]["path"])
    found = problems(manifest, link, Git(args.core_git))
    print(json.dumps({"libraryRev": lib.run("rev-parse", args.rev).stdout.decode().strip(), "zanoGitlink": link,
                      "sourceMapPaths": len(manifest["sourceMap"]), "problems": found}, indent=1))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())

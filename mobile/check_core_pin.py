#!/usr/bin/env python3
"""Verify the mobile SDK producer pins against git objects, for one explicit source profile.

--profile legacy: mobile/zano-mobile-sdk.json, the retained original core lineage. Checks, without
building or checking anything out:
  * this repository's Zano gitlink (at --rev) is the manifest core commit;
  * the core chain is exactly base -> each listed commit (first parent) -> tip;
  * every source-map path holds its pinned sha256/size at the tip and got those
    final bytes in its listed commit, and no other path differs from the base;
  * the core submodule gitlinks are unchanged from the base;
  * the Android composition commit holds every app composition delta and none of
    the project overlays; the Apple composition commit holds both;
  * no forbidden path exists at the tip.

--profile snapshot: mobile/zano-mobile-sdk-snapshot.json, the maintained source snapshot. Checks:
  * the Zano gitlink is the profile root commit, which resolves with the declared tree and no parent;
  * every root tree entry matches the declared source census (mode, sha256, size and path of each
    blob; commit of each gitlink), the gitlinks are the declared submodule pins and the omitted
    paths are absent;
  * the app composition deltas and project overlays carry their pinned bytes at the root, and no
    forbidden path exists;
  * the version facts read from the root's CMakeLists.txt and src/version.h.in, with the root commit
    as COMMIT label, give the declared expected version of both compositions;
  * the Android inputs, the iOS producer configuration and closure, and both producer scripts are
    the exact library files the profile pins; each names the root; the Android core headers and
    every closure row resolve to their bytes, and the closure rows give the declared census;
  * the legacy profile files are still the retained bytes;
  * historical identifiers are recorded only: none is resolved and none is used as a live pin.

Usage: python3 -I mobile/check_core_pin.py --profile {legacy,snapshot} --core-git CORE_REPO [--rev REV | --staged]
CORE_REPO is any git repository holding the profile's core commits (the legacy profile needs the
original lineage; the snapshot profile needs only the snapshot root, for example the initialized
Zano submodule). Library modes (reported as "mode"):
  working   (default) the Zano gitlink of HEAD; the profile and every file it pins from the working tree
  staged    (--staged) the Zano gitlink of the index; files from the working tree
  revision  (--rev REV) the gitlink and every library file (profile manifest, inputs, configuration,
            closure, captured inputs, producer scripts, retained legacy files) from commit REV itself
A profile, pinned file or required field that is missing or unavailable is a listed problem.
Standard library only. Exit 0 when every check passes; findings are printed as JSON.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIB = HERE.parent
MANIFEST = HERE / "zano-mobile-sdk.json"
SNAPSHOT_MANIFEST = HERE / "zano-mobile-sdk-snapshot.json"
SNAPSHOT_SCHEMA = "zano-mobile-sdk-snapshot-profile"
SNAPSHOT_PROFILE = "maintained-snapshot-v1"
ANDROID = "android-arm64-v8a-testnet"
APPLE = "apple-iphoneos-iphonesimulator-testnet"
LEGACY_ONLY_KEYS = ("baseCommit", "chain", "sourceMap", "submodulesUnchangedFromBase", "historyGap",
                    "currentArtifactEvidence", "versionOrigin")
OBJECT_ID = re.compile(r"[0-9a-f]{40}")


class Git:
    def __init__(self, repo):
        self.repo = str(repo)

    def run(self, *args, check=True, data=None):
        proc = subprocess.run(["git", "-C", self.repo, *args], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
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

    def commit_identity(self, commit):
        """(tree, [parents]) from the commit object's header; the object must be a commit."""
        if self.run("cat-file", "-t", commit).stdout.decode().strip() != "commit":
            raise LookupError("%s is not a commit" % commit)
        header = self.run("cat-file", "commit", commit).stdout.split(b"\n\n", 1)[0].decode()
        tree = [line[5:] for line in header.splitlines() if line.startswith("tree ")]
        parents = [line[7:] for line in header.splitlines() if line.startswith("parent ")]
        if len(tree) != 1:
            raise LookupError("%s has no single tree" % commit)
        return tree[0], parents

    def entries(self, rev):
        """[(path, mode, kind, object)] of every tree entry under rev (recursive)."""
        found = []
        for record in self.run("ls-tree", "-r", "-z", rev).stdout.decode().split("\0"):
            if record:
                meta, path = record.split("\t", 1)
                mode, kind, obj = meta.split()
                found.append((path, mode, kind, obj))
        return found

    def blobs(self, specs):
        """{spec: bytes or None} for <rev>:<path> specs, read in one cat-file --batch."""
        out = self.run("cat-file", "--batch", data="".join(s + "\n" for s in specs).encode()).stdout
        found, at = {}, 0
        for spec in specs:
            end = out.index(b"\n", at)
            header = out[at:end].split()
            if len(header) != 3 or header[1] != b"blob":
                found[spec] = None
                at = end + 1
                continue
            size = int(header[2])
            found[spec] = out[end + 1:end + 1 + size]
            at = end + 1 + size + 1
        return found


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


# --------------------------------------------------------------------------
# maintained snapshot profile
# --------------------------------------------------------------------------

def read_library_file(rel):
    """Bytes of a regular library working-tree file, or None."""
    path = LIB / rel
    if path.is_symlink() or not path.is_file():
        return None
    return path.read_bytes()


def revision_reader(lib, commit):
    """A read_lib for commit: the bytes of a regular file (mode 100644/100755) in that commit's tree, or None."""
    def read(rel):
        listing = lib.run("ls-tree", "-z", commit, "--", rel, check=False)
        record = listing.stdout.decode().rstrip("\0")
        if listing.returncode != 0 or not record or "\0" in record:
            return None
        meta, path = record.split("\t", 1)
        mode, kind, obj = meta.split()
        if path != rel or kind != "blob" or mode not in ("100644", "100755"):
            return None
        return lib.run("cat-file", "blob", obj).stdout
    return read


# Required fields (dotted names) of each profile document; a list holds the spec of its rows.
ROW = {"path": str, "sha256": str, "size": int}
SNAPSHOT_REQUIRED = {
    "core": {"path": str, "commit": str, "tree": str, "parents": list, "provenanceNote": ROW},
    "sourceCensus": {"sha256": str, "blobCount": int, "blobBytes": int, "gitlinkCount": int},
    "submodules": dict,
    "omittedPaths": list,
    "appComposition": {"deltas": [ROW], "projectOverlays": [ROW], "forbiddenPaths": [{"path": str}]},
    "sdkVersion": {"commitLabel": str, "expectedVersion": str,
                   "sourceVersion": {"cmakeVersion": str, "projectVersion": str, "buildNumber": int}},
    "compositions": {
        ANDROID: {"sourceCommit": str, "expectedVersion": str,
                  "producerRecipe": {"script": str, "scriptSha256": str, "inputs": str, "inputsSha256": str}},
        APPLE: {"sourceCommit": str, "expectedVersion": str, "versionCommitLabel": str, "producerConfig": str,
                "producerConfigSha256": str, "sdkCensus": {"sha256": str, "fileCount": int, "totalBytes": int},
                "closure": {"path": str, "sha256": str}, "sdkProducer": {"path": str, "sha256": str}}},
    "qualification": {"status": str},
    "historicalReferences": {"legacyProfile": {"files": dict}},
}
INPUTS_REQUIRED = {"schema": str, "version": int, "composition": str, "sourceCommit": str,
                   "headers": [{"from": str, "path": str, "sha256": str, "size": int}]}
CONFIG_REQUIRED = {"schema": str, "version": int, "coreCommit": str, "versionCommitLabel": str, "expectedVersion": str,
                   "sourceVersion": dict,
                   "composition": {"deltas": [ROW], "projectOverlays": {"paths": list}, "forbiddenPaths": list}}
CLOSURE_REQUIRED = {"schema": str, "version": int, "composition": str, "sourceCommit": str, "census": dict,
                    "submodules": dict, "captured": {"root": str, "paths": list},
                    "files": [{"path": str, "sha256": str, "size": int, "executable": bool, "from": str}]}
LEGACY_REQUIRED = {
    "core": {"path": str, "baseCommit": str, "commit": str, "chain": [{"commit": str}]},
    "sourceMap": [{"path": str, "sha256": str, "size": int, "finalCommit": str}],
    "submodulesUnchangedFromBase": dict,
    "appComposition": {"deltas": [{"path": str, "sha256": str}], "projectOverlays": list,
                       "forbiddenPaths": [{"path": str}]},
    "compositions": {ANDROID: {"sourceCommit": str}, APPLE: {"sourceCommit": str}},
}


def missing_fields(doc, spec, prefix=""):
    """Dotted names of the required fields of spec that doc lacks or holds with another type."""
    found = []
    for key, want in spec.items():
        name = prefix + key
        if not isinstance(doc, dict) or key not in doc:
            found.append(name)
            continue
        value = doc[key]
        if isinstance(want, dict):
            found.extend(missing_fields(value, want, name + "."))
        elif isinstance(want, list):
            if not isinstance(value, list):
                found.append(name)
                continue
            for i, row in enumerate(value):
                found.extend(missing_fields(row, want[0], "%s[%d]." % (name, i)))
        elif not isinstance(value, want) or (want is int and isinstance(value, bool)):
            found.append(name)
    return found


def source_census(entries, data):
    """The declared source census of a tree: sha256 over '<mode> <sha256> <size> <path>' per blob and
    '160000 <commit> - <path>' per gitlink, one line each in path byte order."""
    h = hashlib.sha256()
    blobs = size = links = 0
    for path, mode, kind, obj in sorted(entries, key=lambda e: e[0].encode()):
        if kind == "blob":
            blob = data[path]
            h.update(("%s %s %d %s\n" % (mode, sha256(blob), len(blob), path)).encode())
            blobs += 1
            size += len(blob)
        elif kind == "commit":
            h.update(("160000 %s - %s\n" % (obj, path)).encode())
            links += 1
        else:
            raise LookupError("unexpected tree entry kind %s at %s" % (kind, path))
    return {"sha256": h.hexdigest(), "blobCount": blobs, "blobBytes": size, "gitlinkCount": links}


def closure_census(rows):
    """sdk_producer census_digest of the closure rows, in its directory-walk order."""
    h = hashlib.sha256()
    for row in sorted(rows, key=lambda r: r["path"].split("/")):
        h.update(("%s  %d  %s\n" % (row["sha256"], row["size"], row["path"])).encode("utf-8"))
    return {"sha256": h.hexdigest(), "fileCount": len(rows), "totalBytes": sum(r["size"] for r in rows)}


def version_facts(cmakelists, template):
    """(sourceVersion, COMMIT route present) read from the root's CMakeLists.txt and src/version.h.in."""
    if cmakelists is None or template is None:
        return None, False
    cmake, text = cmakelists.decode("utf-8"), template.decode("utf-8")
    values = dict(re.findall(r'^#define\s+(PROJECT_(?:MAJOR|MINOR)_VERSION|PROJECT_REVISION)\s+"([^"]*)"', text, re.M))
    number = re.search(r"^#define\s+PROJECT_VERSION_BUILD_NO\s+(\d+)", text, re.M)
    version = re.search(r'^set\(VERSION "([^"]+)"\)', cmake, re.M)
    if len(values) != 3 or not number or not version or '#define BUILD_COMMIT_ID "@VERSION@"' not in text:
        return None, False
    facts = {"cmakeVersion": version.group(1), "buildNumber": int(number.group(1)),
             "projectVersion": "%s.%s.%s" % (values["PROJECT_MAJOR_VERSION"], values["PROJECT_MINOR_VERSION"],
                                             values["PROJECT_REVISION"])}
    route = "elseif(DEFINED COMMIT)" in cmake and 'set(VERSION "${VERSION}-g${COMMIT}")' in cmake
    return facts, route


def object_ids(value):
    if isinstance(value, dict):
        return set().union(*(object_ids(v) for v in value.values())) if value else set()
    if isinstance(value, list):
        return set().union(*(object_ids(v) for v in value)) if value else set()
    return {value} if isinstance(value, str) and OBJECT_ID.fullmatch(value) else set()


def legacy_keys(value):
    if isinstance(value, dict):
        return {k for k in value if k in LEGACY_ONLY_KEYS} | set().union(set(), *(legacy_keys(v) for v in value.values()))
    if isinstance(value, list):
        return set().union(set(), *(legacy_keys(v) for v in value))
    return set()


def pinned_library_bytes(read_lib, rel, pinned, what, found):
    data = read_lib(rel)
    if data is None:
        found.append("%s is unavailable: %s" % (what, rel))
    elif sha256(data) != pinned:
        found.append("%s is not the library file the snapshot profile pins: %s" % (what, rel))
    else:
        return data
    return None


def library_json(read_lib, rel, pinned, what, found, required):
    data = pinned_library_bytes(read_lib, rel, pinned, what, found)
    if data is None:
        return None
    try:
        doc = json.loads(data.decode("utf-8"))
    except ValueError:
        found.append("%s is not valid JSON: %s" % (what, rel))
        return None
    absent = missing_fields(doc, required)
    if absent:
        found.extend("%s lacks required field %s: %s" % (what, name, rel) for name in absent)
        return None
    return doc


def snapshot_problems(profile, lib_gitlink, core, read_lib=read_library_file):
    """Findings of the snapshot profile against its core repository and this library's files."""
    if not isinstance(profile, dict) or profile.get("schema") != SNAPSHOT_SCHEMA or profile.get("version") != 1 or \
            profile.get("sourceProfile") != SNAPSHOT_PROFILE:
        return ["the snapshot profile declaration (schema, version, sourceProfile) is missing or wrong"]
    absent = missing_fields(profile, SNAPSHOT_REQUIRED)
    if absent:
        return ["the snapshot profile lacks required field " + name for name in absent]
    found = []
    live = {k: v for k, v in profile.items() if k != "historicalReferences"}
    mixed = sorted(legacy_keys(live))
    if mixed:
        found.append("the snapshot profile carries legacy lineage fields: " + ", ".join(mixed))
    historical = object_ids(profile["historicalReferences"])
    for value in sorted(object_ids(live) & historical):
        found.append("a live snapshot pin names a historical reference: " + value)
    pin = profile["core"]
    root = pin["commit"]
    if lib_gitlink != root:
        found.append("library Zano gitlink %s is not the snapshot root %s" % (lib_gitlink, root))
    try:
        tree, parents = core.commit_identity(root)
    except LookupError as error:
        found.append("snapshot root %s is unavailable: %s" % (root, error))
        return found
    if tree != pin["tree"]:
        found.append("snapshot root %s has tree %s, not the declared %s" % (root, tree, pin["tree"]))
    if parents or pin.get("parents") != []:
        found.append("snapshot root must be a declared root commit without parents (has %d)" % len(parents))
    entries = core.entries(root)
    blob_paths = [p for p, _m, kind, _o in entries if kind == "blob"]
    read = core.blobs([root + ":" + p for p in blob_paths])
    at_root = {p: read[root + ":" + p] for p in blob_paths}
    if any(v is None for v in at_root.values()):
        found.append("snapshot root blobs are unavailable")
        return found
    declared = profile["sourceCensus"]
    measured = source_census(entries, at_root)
    if measured != {k: declared.get(k) for k in measured}:
        found.append("the root tree differs from the declared source census")
    links = {p: o for p, _m, kind, o in entries if kind == "commit"}
    if links != profile["submodules"]:
        found.append("core submodule gitlinks differ from the declared snapshot pins")
    present = {p for p, _m, _k, _o in entries}
    for omitted in profile["omittedPaths"]:
        if omitted in present or any(p.startswith(omitted + "/") for p in present):
            found.append("omitted path present at the root: " + omitted)

    def pinned(path, sha, size):
        blob = at_root.get(path)
        return blob is not None and sha256(blob) == sha and len(blob) == size

    note = pin["provenanceNote"]
    if not pinned(note["path"], note["sha256"], note["size"]):
        found.append("the root provenance note is not its pinned bytes: " + note["path"])
    app = profile["appComposition"]
    for row in app["deltas"] + app["projectOverlays"]:
        if not pinned(row["path"], row["sha256"], row["size"]):
            found.append("snapshot root misses composition bytes: " + row["path"])
    for forbidden in app["forbiddenPaths"]:
        if forbidden["path"] in at_root:
            found.append("forbidden path present at the root: " + forbidden["path"])

    version = profile["sdkVersion"]
    facts, route = version_facts(at_root.get("CMakeLists.txt"), at_root.get("src/version.h.in"))
    if facts is None or facts != version["sourceVersion"]:
        found.append("the root version facts are not the declared sourceVersion")
    if not route:
        found.append("the root CMakeLists.txt has no COMMIT version route")
    if version["commitLabel"] != root:
        found.append("the snapshot version label is not the root commit")
    sv = version["sourceVersion"]
    expected = "%s.%d[%s-g%s]" % (sv["projectVersion"], sv["buildNumber"], sv["cmakeVersion"], root)
    if version["expectedVersion"] != expected:
        found.append("the declared expected version %s is not %s" % (version["expectedVersion"], expected))
    android, apple = profile["compositions"][ANDROID], profile["compositions"][APPLE]
    for label, comp in (("android", android), ("apple", apple)):
        if comp["sourceCommit"] != root:
            found.append("%s composition is not the snapshot root" % label)
        if comp["expectedVersion"] != expected:
            found.append("%s composition expects %s, not %s" % (label, comp["expectedVersion"], expected))
    if apple["versionCommitLabel"] != root:
        found.append("apple versionCommitLabel is not the snapshot root")
    if profile["qualification"]["status"] != "unqualified":
        found.append("the snapshot profile claims a qualification no measurement has given")

    recipe = android["producerRecipe"]
    for rel, sha, what in ((recipe["script"], recipe["scriptSha256"], "the Android producer script"),
                           (apple["sdkProducer"]["path"], apple["sdkProducer"]["sha256"], "the iOS SDK producer")):
        pinned_library_bytes(read_lib, rel, sha, what, found)
    inputs = library_json(read_lib, recipe["inputs"], recipe["inputsSha256"], "the Android inputs", found,
                          INPUTS_REQUIRED)
    if inputs is not None:
        if inputs.get("schema") != "zano-mobile-android-producer-inputs" or inputs.get("version") != 1 or \
                inputs.get("sourceProfile") != SNAPSHOT_PROFILE or inputs.get("composition") != ANDROID or \
                inputs.get("sourceCommit") != root:
            found.append("the Android inputs are not the snapshot profile inputs of the root")
        for header in (h for h in inputs.get("headers", []) if h["from"] == "core"):
            if not pinned(header["path"], header["sha256"], header["size"]):
                found.append("Android core header differs from its root pin: " + header["path"])
    config = library_json(read_lib, apple["producerConfig"], apple["producerConfigSha256"], "the iOS producer configuration",
                          found, CONFIG_REQUIRED)
    if config is not None:
        if config.get("schema") != "zano-ios-sdk-producer" or config.get("version") != 1 or \
                config.get("sourceProfile") != SNAPSHOT_PROFILE or config.get("coreCommit") != root or \
                config.get("versionCommitLabel") != root or config.get("expectedVersion") != expected or \
                config.get("sourceVersion") != sv:
            found.append("the iOS producer configuration is not the snapshot configuration of the root")
        if [(d["path"], d["sha256"], d["size"]) for d in config["composition"]["deltas"]] != \
                [(d["path"], d["sha256"], d["size"]) for d in app["deltas"]] or \
                config["composition"]["projectOverlays"]["paths"] != [o["path"] for o in app["projectOverlays"]] or \
                config["composition"]["forbiddenPaths"] != app["forbiddenPaths"]:
            found.append("the iOS producer composition differs from the profile app composition")
    closure = library_json(read_lib, apple["closure"]["path"], apple["closure"]["sha256"], "the iOS closure", found,
                           CLOSURE_REQUIRED)
    if closure is not None:
        found.extend(closure_problems(closure, apple, profile, root, at_root, core, read_lib))
    retained = profile["historicalReferences"]["legacyProfile"]["files"]
    for rel, sha in sorted(retained.items()):
        data = read_lib(rel)
        if data is None:
            found.append("a retained legacy profile file is unavailable: " + rel)
        elif sha256(data) != sha:
            found.append("a retained legacy profile file changed: " + rel)
    return found


def closure_problems(closure, apple, profile, root, at_root, core, read_lib):
    found = []
    census = {k: apple["sdkCensus"][k] for k in ("sha256", "fileCount", "totalBytes")}
    if closure.get("schema") != "zano-ios-sdk-closure" or closure.get("version") != 1 or \
            closure.get("sourceProfile") != SNAPSHOT_PROFILE or closure.get("composition") != APPLE or \
            closure.get("sourceCommit") != root or closure.get("census") != census:
        found.append("the iOS closure is not the snapshot closure of the root and its census")
    for link, commit in closure["submodules"].items():
        if profile["submodules"].get(link) != commit:
            found.append("closure submodule %s is not the root pin" % link)
    rows = closure["files"]
    if closure_census(rows) != census:
        found.append("the closure rows do not give the declared census")
    modes = {}
    by_link = {}
    for row in rows:
        rel = row["path"]
        if row["from"] == "core":
            blob = at_root.get(rel)
            if blob is None or sha256(blob) != row["sha256"] or len(blob) != row["size"]:
                found.append("closure core path does not resolve to its root pin: " + rel)
            modes[rel] = row["executable"]
        elif row["from"] == "submodule":
            link = next((l for l in closure["submodules"] if rel.startswith(l + "/")), None)
            if link is None:
                found.append("closure submodule path outside every pinned submodule: " + rel)
                continue
            by_link.setdefault(link, []).append(row)
        elif row["from"] == "captured" and rel in closure["captured"]["paths"]:
            data = read_lib(closure["captured"]["root"] + "/" + rel)
            if data is None or sha256(data) != row["sha256"] or len(data) != row["size"]:
                found.append("captured closure input is not its pinned bytes: " + rel)
        else:
            found.append("closure path has no admitted resolution: " + rel)
    tree_modes = {p: m for p, m, kind, _o in core.entries(root) if kind == "blob"}
    for rel, executable in modes.items():
        if executable != (tree_modes.get(rel) == "100755"):
            found.append("closure mode differs from the root tree: " + rel)
    for link, link_rows in sorted(by_link.items()):
        sub = Git(Path(core.repo) / link)
        commit = closure["submodules"][link]
        try:
            data = sub.blobs(["%s:%s" % (commit, r["path"][len(link) + 1:]) for r in link_rows])
            sub_modes = {link + "/" + p: m for p, m, kind, _o in sub.entries(commit) if kind == "blob"}
        except LookupError as error:
            found.append("core submodule %s at %s is unavailable: %s" % (link, commit, error))
            continue
        for r in link_rows:
            blob = data["%s:%s" % (commit, r["path"][len(link) + 1:])]
            if blob is None or sha256(blob) != r["sha256"] or len(blob) != r["size"]:
                found.append("closure submodule path does not resolve to its pin: " + r["path"])
            elif r["executable"] != (sub_modes.get(r["path"]) == "100755"):
                found.append("closure mode differs from the submodule tree: " + r["path"])
    return found


def library_gitlink(lib, path, rev, staged):
    if staged:
        fields = lib.run("ls-files", "-s", "--", path).stdout.decode().split()
        return fields[1] if len(fields) >= 4 and fields[0] == "160000" else None
    return lib.gitlinks(rev).get(path)


def legacy_problems(manifest, lib_gitlink, core):
    """problems() of the retained lineage manifest, after its declaration and required fields."""
    if not isinstance(manifest, dict) or manifest.get("schema") != "zano-mobile-sdk-producer" or "sourceProfile" in manifest:
        return ["the legacy profile is not the retained lineage manifest"]
    absent = missing_fields(manifest, LEGACY_REQUIRED)
    if absent:
        return ["the legacy profile lacks required field " + name for name in absent]
    return problems(manifest, lib_gitlink, core)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--profile", required=True, choices=("legacy", "snapshot"))
    parser.add_argument("--core-git", required=True)
    where = parser.add_mutually_exclusive_group()
    where.add_argument("--rev", help="revision mode: every library read comes from this commit")
    where.add_argument("--staged", action="store_true", help="staged mode: index gitlink, working-tree files")
    args = parser.parse_args(argv)
    lib = Git(LIB)
    path = (MANIFEST if args.profile == "legacy" else SNAPSHOT_MANIFEST).relative_to(LIB).as_posix()
    report = {"profile": args.profile}
    if args.rev is not None:
        resolved = lib.run("rev-parse", "--verify", "--quiet", args.rev + "^{commit}", check=False)
        commit = resolved.stdout.decode().strip()
        report.update(mode="revision", libraryRev=commit or args.rev)
        if resolved.returncode != 0 or not commit:
            report["problems"] = ["library revision %s is not an available commit" % args.rev]
            print(json.dumps(report, indent=1))
            return 1
        read_lib, where_text = revision_reader(lib, commit), "revision " + commit
    else:
        report.update(mode="staged" if args.staged else "working",
                      libraryRev="index" if args.staged else lib.run("rev-parse", "HEAD").stdout.decode().strip())
        read_lib, where_text = read_library_file, "the working tree"
    data = read_lib(path)
    try:
        manifest = None if data is None else json.loads(data.decode("utf-8"))
    except ValueError:
        manifest = None
    if not isinstance(manifest, dict):
        report["problems"] = ["the %s profile %s is unavailable or not a JSON object in %s"
                              % (args.profile, path, where_text)]
        print(json.dumps(report, indent=1))
        return 1
    core_path = manifest["core"].get("path") if isinstance(manifest.get("core"), dict) else None
    link = None
    if isinstance(core_path, str):
        link = library_gitlink(lib, core_path, report["libraryRev"], args.staged)
    report["zanoGitlink"] = link
    if args.profile == "legacy":
        found = legacy_problems(manifest, link, Git(args.core_git))
        if isinstance(manifest.get("sourceMap"), list):
            report["sourceMapPaths"] = len(manifest["sourceMap"])
    else:
        found = snapshot_problems(manifest, link, Git(args.core_git), read_lib)
        if not missing_fields(manifest, {"core": {"commit": str}, "sourceCensus": {"sha256": str}}):
            report.update(snapshotRoot=manifest["core"]["commit"], sourceCensus=manifest["sourceCensus"]["sha256"])
    report["problems"] = found
    print(json.dumps(report, indent=1))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())

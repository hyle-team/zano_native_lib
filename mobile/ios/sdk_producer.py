#!/usr/bin/env python3
"""Zano mobile SDK producer for Apple (iOS device + simulator, arm64), owned by zano_native_lib.

The one implementation of the SDK-specific producer steps. Every path here is relative to this
wrapper checkout (the directory holding mobile/); nothing names a consuming app, its mount point,
its Android lock or its own SDK copies.

Interface (INTERFACE below; a consuming app binds these names and adds its own host inputs):
  load_config()                       mobile/ios/sdk-producer.json and its sha256
  admit_closure / materialize_closure mobile/ios/closure.json resolved through the pinned core
                                      (Zano), its pinned submodule commits and mobile/ios/captured
  snapshot_from_closure               a composed snapshot (composition.json + source) of the closure,
                                      admitted with admit_snapshot
  compose_snapshot / admit_snapshot   composition and admission of a snapshot; the project overlays
                                      resolve from <wrapper>/<projectOverlays.root>
  header_closure / resolve_header_closure / source_header_plan
                                      the library-owned consumer include-path set and its resolution
  toolchain, build_env, configure_argv, build_sdk, check_archive, check_wallet_archive,
  check_compile_commands, built_version
                                      the per-slice CMake build of the SDK targets and its checks

Command (no toolchain, no network, nothing outside --scratch is written):
  plan --scratch NEW_DIR   materialize and admit the closure snapshot, resolve the header closure
                           against it, and print the producer plan.
A real build (build_sdk) runs only on macOS with Xcode, through a consuming app's stage producer.
Standard library only; run as python3 -I.
"""
import argparse
import gzip
import hashlib
import importlib.util
import io
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import time
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
WRAPPER = HERE.parents[1]
CONFIG_PATH = HERE / "sdk-producer.json"
APPLE_COMPOSITION = "apple-iphoneos-iphonesimulator-testnet"

CHUNK = 1 << 20


# Compiler/linker selection that must never leak into the SDK build.
STRIPPED_ENV = (
    "CFLAGS", "CXXFLAGS", "CPPFLAGS", "OBJCFLAGS", "LDFLAGS", "CPATH",
    "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJC_INCLUDE_PATH", "LIBRARY_PATH",
    "SDKROOT", "MACOSX_DEPLOYMENT_TARGET", "IPHONEOS_DEPLOYMENT_TARGET",
    "CC", "CXX", "CMAKE_TOOLCHAIN_FILE", "CMAKE_GENERATOR", "CMAKE_PREFIX_PATH",
    "OPENSSL_ROOT_DIR", "BOOST_ROOT", "BOOSTROOT", "ZANO_USE_SYSTEM_BOOST",
)


class Refusal(Exception):
    """A precondition or verification failed; nothing is reported as success."""


def refuse(message):
    raise Refusal(message)


def say(message):
    print("[zano-ios-producer] " + message, flush=True)


def open_regular(path):
    fd = os.open(str(path), os.O_RDONLY | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0))
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode):
        os.close(fd)
        refuse("not a regular file: %s" % path)
    return fd


def digest_file(path):
    fd = open_regular(path)
    try:
        h = hashlib.sha256()
        size = 0
        while True:
            block = os.read(fd, CHUNK)
            if not block:
                break
            h.update(block)
            size += len(block)
        return h.hexdigest(), size
    finally:
        os.close(fd)


def copy_bytes(source, dest, executable=False):
    """Copies the bytes of a regular file into a new file; returns (sha256, size)."""
    fd = open_regular(source)
    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0)
        out = os.open(str(dest), flags, 0o755 if executable else 0o644)
        try:
            h = hashlib.sha256()
            size = 0
            while True:
                block = os.read(fd, CHUNK)
                if not block:
                    break
                h.update(block)
                size += len(block)
                view = memoryview(block)
                while view:
                    written = os.write(out, view)
                    view = view[written:]
        finally:
            os.close(out)
        return h.hexdigest(), size
    finally:
        os.close(fd)


def write_new(dest, data, mode=0o644):
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | getattr(os, "O_CLOEXEC", 0)
    out = os.open(str(dest), flags, mode)
    try:
        view = memoryview(data)
        while view:
            written = os.write(out, view)
            view = view[written:]
    finally:
        os.close(out)


def inside(child, parent):
    child, parent = str(child), str(parent)
    return child == parent or child.startswith(parent.rstrip("/") + "/")


def canonical_dir(value, what):
    """An existing absolute directory whose path has no symlink component."""
    if not value:
        refuse("%s is not set" % what)
    path = Path(value)
    if not path.is_absolute():
        refuse("%s must be an absolute path: %s" % (what, value))
    try:
        info = os.lstat(str(path))
    except FileNotFoundError:
        refuse("%s does not exist: %s" % (what, value))
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
        refuse("%s is not a real directory: %s" % (what, value))
    if os.path.realpath(str(path)) != str(path).rstrip("/"):
        refuse("%s is redirected or not canonical: %s" % (what, value))
    return Path(os.path.realpath(str(path)))


def new_path(value, what):
    """An absent absolute path whose parent is a canonical directory."""
    if not value:
        refuse("%s is not set" % what)
    path = Path(value)
    if not path.is_absolute():
        refuse("%s must be an absolute path: %s" % (what, value))
    parent = canonical_dir(str(path.parent), what + " parent")
    return parent / path.name


def no_overlap(named):
    items = list(named.items())
    for i, (a_name, a) in enumerate(items):
        for b_name, b in items[i + 1:]:
            if inside(a, b) or inside(b, a):
                refuse("%s (%s) overlaps %s (%s)" % (a_name, a, b_name, b))


def census(root):
    """Every regular file under root as (relative path, size, sha256); refuses links/specials."""
    entries = []

    def walk(directory, prefix):
        with os.scandir(str(directory)) as it:
            children = sorted(it, key=lambda e: e.name)
        for entry in children:
            rel = prefix + entry.name
            info = entry.stat(follow_symlinks=False)
            if stat.S_ISDIR(info.st_mode):
                walk(Path(entry.path), rel + "/")
            elif stat.S_ISREG(info.st_mode):
                sha, size = digest_file(entry.path)
                entries.append((rel, size, sha))
            else:
                refuse("not a regular file or directory (symlink/special): %s" % entry.path)

    walk(root, "")
    return entries


def census_digest(entries):
    h = hashlib.sha256()
    for rel, size, sha in entries:
        h.update(("%s  %d  %s\n" % (sha, size, rel)).encode("utf-8"))
    return {"sha256": h.hexdigest(), "fileCount": len(entries), "totalBytes": sum(e[1] for e in entries)}


def make_read_only(root, include_root=True):
    for directory, dirs, files in os.walk(str(root), topdown=False):
        for name in files:
            path = os.path.join(directory, name)
            mode = os.lstat(path).st_mode
            os.chmod(path, 0o555 if mode & 0o111 else 0o444)
        if include_root or directory != str(root):
            os.chmod(directory, 0o555)


def publish(incoming, final):
    """Renames a finished, still-writable directory into place, then seals its root."""
    if os.path.lexists(str(final)):
        refuse("%s appeared while it was being produced" % final)
    os.rename(str(incoming), str(final))
    os.chmod(str(final), 0o555)


def load_config():
    sha, _ = digest_file(CONFIG_PATH)
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    if config.get("schema") != "zano-ios-sdk-producer" or config.get("version") != 1:
        refuse("unknown producer configuration schema in %s" % CONFIG_PATH)
    label = config["versionCommitLabel"]
    if not re.fullmatch(r"[0-9a-f]{40}-[0-9a-z-]+", label) or not label.startswith(config["coreCommit"] + "-"):
        refuse("versionCommitLabel is not <coreCommit>-<suffix>")
    sv = config["sourceVersion"]
    expected = "%s.%d[%s-g%s]" % (sv["projectVersion"], sv["buildNumber"], sv["cmakeVersion"], label)
    if config["expectedVersion"] != expected:
        refuse("expectedVersion does not follow from sourceVersion and versionCommitLabel")
    for delta in config["composition"]["deltas"]:
        if not re.fullmatch(r"[0-9a-f]{64}", delta["sha256"]):
            refuse("configuration delta has no real digest: %s" % delta["path"])
        if delta["size"] is not None and (type(delta["size"]) is not int or delta["size"] <= 0):
            refuse("configuration delta has an invalid size: %s" % delta["path"])
        safe_relative(delta["path"])
    return config, sha


def safe_relative(rel):
    parts = rel.split("/")
    if rel.startswith("/") or any(p in ("", ".", "..") for p in parts):
        refuse("unsafe relative path: %s" % rel)
    return rel


def run(argv, log=None, cwd=None, env=None, timeout=None, what=None):
    """Runs a real command; returns stdout text. Output goes to the log if given.

    Every log= path is one this producer creates for its own public build
    commands (core, Boost, OpenSSL, R1 staging and the injected R1 adapter
    passes). When such a command fails or times out, the first primary
    compiler/linker/CMake errors of this command's part of the log
    (emit_primary_diagnostics) and then the bounded tail of the log
    (emit_log_tail), both labelled `what` or the log file name, are printed;
    then the original refusal or TimeoutExpired propagates unchanged; nothing
    continues after it."""
    if log is None:
        result = subprocess.run([str(a) for a in argv], cwd=cwd, env=env, timeout=timeout,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        if result.returncode != 0:
            refuse("command failed (%d): %s\n%s" % (result.returncode, " ".join(map(str, argv)),
                                                     result.stderr.decode("utf-8", "replace")[-4000:]))
        return result.stdout.decode("utf-8", "replace")
    label = what or Path(str(log)).name
    segment = None
    try:
        with open(str(log), "ab") as handle:
            handle.write(("$ " + " ".join(map(str, argv)) + "\n").encode("utf-8"))
            handle.flush()
            segment = os.fstat(handle.fileno()).st_size  # this command's output starts here
            result = subprocess.run([str(a) for a in argv], cwd=cwd, env=env, timeout=timeout,
                                    stdout=handle, stderr=subprocess.STDOUT, check=False)
    except subprocess.TimeoutExpired:
        emit_primary_diagnostics(log, label, segment)
        emit_log_tail(log, label)
        raise
    if result.returncode != 0:
        emit_primary_diagnostics(log, label, segment)
        emit_log_tail(log, label)
        refuse("command failed (%d), see %s: %s" % (result.returncode, log, " ".join(map(str, argv))))
    return ""


# Primary diagnostics of a failed owned build command. A parallel C++ build's
# last lines are often only template/macro notes and "N errors generated"
# summaries, so the tail alone can lose the actual error. Only the failed
# command's own segment of its owned log is scanned, at most LOG_SCAN_MAX_BYTES
# of it (larger: tail only), one line read at a time with at most
# LOG_SCAN_LINE_BYTES per read. The printed selection is bounded to
# LOG_PRIMARY_BYTES/LOG_PRIMARY_LINES, so with the tail the total printed log
# content never exceeds LOG_DIAGNOSTIC_TOTAL_BYTES.
LOG_SCAN_MAX_BYTES = 256 << 20


LOG_SCAN_LINE_BYTES = 8192


LOG_PRIMARY_MAX_ERRORS = 8


LOG_PRIMARY_BEFORE = 2


LOG_PRIMARY_AFTER = 4


LOG_PRIMARY_LINE_CHARS = 400


LOG_PRIMARY_BYTES = 6144


LOG_PRIMARY_LINES = 48


# A primary line is an error-severity diagnostic at the start of a line:
# "<file>:<line>[:<col>]: [fatal ]error: ", "<tool>: error: " (clang, collect2,
# -Werror promotions included), a linker line that is not a warning, Apple's
# "Undefined symbols for architecture", GNU "undefined reference to", or
# "CMake Error". note:/warning: lines, "N errors generated" and make's
# "*** [...] Error N" summaries are not primary; they stay in the tail.
PRIMARY_ERROR = re.compile(
    r"^(?:[^\s:][^:]*?(?::\d+){0,2}: +)?(?:fatal )?error: "
    r"|^(?:ld|ld64|ld\.lld|ld\.gold|ld\.bfd|\S*/ld): (?!warning)"
    r"|^Undefined symbols for architecture "
    r"|: undefined reference to "
    r"|^CMake Error\b")


ANSI_SEQUENCE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)?|[@-Z\\-_])")


def clean_log_line(raw):
    """One log line as printable text: ANSI/terminal sequences removed, any
    other control character (tab kept) replaced by '?'."""
    text = ANSI_SEQUENCE.sub("", raw.decode("utf-8", "replace").rstrip("\r\n"))
    return "".join(c if c == "\t" or c.isprintable() else "?" for c in text)


def emit_primary_diagnostics(log, what, segment):
    """Prints, to stderr, the first LOG_PRIMARY_MAX_ERRORS primary error lines
    of one failed owned command's log segment (offset `segment` to the end),
    each with LOG_PRIMARY_BEFORE/LOG_PRIMARY_AFTER adjacent lines, within the
    fixed LOG_PRIMARY_BYTES/LOG_PRIMARY_LINES bound, and says how many primary
    lines the segment holds and whether the selection was cut. Says so and
    prints nothing else when the log is unreadable, not a regular file,
    oversized or has no primary line; the tail then stands alone. Never raises
    and never decides success: the caller re-raises the original failure."""
    try:
        fd = os.open(str(log), os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode):
                raise OSError("not a regular file")
            if segment is None or not 0 <= segment <= info.st_size:
                raise OSError("command segment offset %r is outside the log" % (segment,))
            size = info.st_size - segment
            if size > LOG_SCAN_MAX_BYTES:
                print("[zano-ios-producer] %s: command output %d bytes exceeds the primary-error scan bound %d; tail only"
                      % (what, size, LOG_SCAN_MAX_BYTES), file=sys.stderr, flush=True)
                return
            os.lseek(fd, segment, os.SEEK_SET)
            selected, total, cut = scan_primary_errors(io.open(fd, "rb", buffering=CHUNK, closefd=False), size)
        finally:
            os.close(fd)
    except (OSError, ValueError) as error:
        print("[zano-ios-producer] %s log %s is unreadable for the primary-error scan: %s; tail only"
              % (what, log, error), file=sys.stderr, flush=True)
        return
    if not total:
        print("[zano-ios-producer] %s: no primary compiler/linker/CMake error line in this command's %d log bytes; tail only"
              % (what, size), file=sys.stderr, flush=True)
        return
    shown = sum(1 for _n, _t, primary in selected if primary)
    print("[zano-ios-producer] --- %s primary errors: %d primary line(s) in this command's %d log bytes; first %d shown"
          " with adjacent lines (bound %d bytes/%d lines)%s ---"
          % (what, total, size, shown, LOG_PRIMARY_BYTES, LOG_PRIMARY_LINES,
             "; selection cut at the bound" if cut else ""), file=sys.stderr)
    previous = None
    for number, text, primary in selected:
        if previous is not None and number != previous + 1:
            print("[%s primary] ..." % what, file=sys.stderr)
        print("[%s primary] %6d%s %s" % (what, number, ">" if primary else "|", text), file=sys.stderr)
        previous = number
    print("[zano-ios-producer] --- end of %s primary errors ---" % what, file=sys.stderr, flush=True)


def scan_primary_errors(stream, limit):
    """Reads at most `limit` bytes line by line; returns (selected, total, cut):
    selected = [(segment line number, cleaned text, is_primary)] in order,
    total = number of primary lines, cut = the bound stopped the selection."""
    selected, before, total, cut = [], [], 0, False
    used = [0, 0]
    after = 0
    number = 0
    remaining = limit
    continuing = False

    def add(entry):
        text = entry[1]
        if len(text) > LOG_PRIMARY_LINE_CHARS:
            text = text[:LOG_PRIMARY_LINE_CHARS] + " [line cut]"
        cost = len(text.encode("utf-8"))
        if used[1] + 1 > LOG_PRIMARY_LINES or used[0] + cost > LOG_PRIMARY_BYTES:
            return False
        used[0] += cost
        used[1] += 1
        selected.append((entry[0], text, entry[2]))
        return True

    while remaining > 0:
        raw = stream.readline(min(LOG_SCAN_LINE_BYTES, remaining))
        if not raw:
            break
        remaining -= len(raw)
        fragment, continuing = continuing, not raw.endswith(b"\n")
        if fragment:
            continue  # rest of an over-long line: neither a line start nor context
        number += 1
        text = clean_log_line(raw)
        primary = bool(PRIMARY_ERROR.search(text))
        if primary:
            total += 1
        if not cut:
            if primary and sum(1 for e in selected if e[2]) < LOG_PRIMARY_MAX_ERRORS:
                chosen = {e[0] for e in selected}
                for entry in before:
                    if entry[0] not in chosen and not add(entry):
                        cut = True
                        break
                if not cut and not add((number, text, True)):
                    cut = True
                after = LOG_PRIMARY_AFTER
            elif primary:
                cut = True  # more primary lines than LOG_PRIMARY_MAX_ERRORS
            elif after > 0:
                after -= 1
                if not add((number, text, False)):
                    cut = True
        before = (before + [(number, text, False)])[-LOG_PRIMARY_BEFORE:]
    return selected, total, cut


# A failed owned build command's log is worker-local; only the bounded primary
# error selection above and this bounded tail of it are copied into the
# provider build output, and only after the failure.
LOG_TAIL_BYTES = 8192


LOG_TAIL_LINES = 80


# Fixed bound of all log content printed for one failure (primary + tail).
LOG_DIAGNOSTIC_TOTAL_BYTES = LOG_PRIMARY_BYTES + LOG_TAIL_BYTES


def emit_log_tail(log, what):
    """Prints at most LOG_TAIL_LINES lines from the last LOG_TAIL_BYTES bytes of
    one owned command log to stderr, control characters replaced. Never raises
    and never decides success: the caller re-raises the original failure."""
    try:
        fd = os.open(str(log), os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode):
                raise OSError("not a regular file")
            start = max(0, info.st_size - LOG_TAIL_BYTES)
            os.lseek(fd, start, os.SEEK_SET)
            data = b""
            while len(data) < LOG_TAIL_BYTES:
                chunk = os.read(fd, LOG_TAIL_BYTES - len(data))
                if not chunk:
                    break
                data += chunk
        finally:
            os.close(fd)
    except OSError as error:
        print("[zano-ios-producer] %s log %s is unreadable: %s" % (what, log, error), file=sys.stderr, flush=True)
        return
    lines = data.decode("utf-8", "replace").splitlines()
    if start > 0 and lines:
        lines = lines[1:]  # the first line may be cut mid-way by the byte bound
    lines = lines[-LOG_TAIL_LINES:]
    clean = ["".join(c if c == "\t" or c.isprintable() else "?" for c in line) for line in lines]
    print("[zano-ios-producer] --- %s failed; last %d line(s) of %s (%d bytes, tail bound %d bytes/%d lines) ---"
          % (what, len(clean), log, info.st_size, LOG_TAIL_BYTES, LOG_TAIL_LINES), file=sys.stderr)
    for line in clean:
        print("[%s] %s" % (what, line), file=sys.stderr)
    print("[zano-ios-producer] --- end of %s log tail ---" % what, file=sys.stderr, flush=True)


def materialize_tree(source_dir, dest_dir, rel_prefix, base_real, chain, excluded, links, top):
    with os.scandir(str(source_dir)) as it:
        children = sorted(it, key=lambda e: e.name)
    for entry in children:
        rel = rel_prefix + entry.name
        if top and entry.name in excluded:
            continue
        info = entry.stat(follow_symlinks=False)
        dest = dest_dir / entry.name
        if stat.S_ISDIR(info.st_mode):
            real = os.path.realpath(entry.path)
            if real in chain:
                refuse("directory cycle at %s" % rel)
            dest.mkdir(mode=0o755)
            materialize_tree(Path(entry.path), dest, rel + "/", base_real, chain | {real}, excluded, links, False)
        elif stat.S_ISREG(info.st_mode):
            copy_bytes(Path(entry.path), dest, executable=bool(info.st_mode & 0o111))
        elif stat.S_ISLNK(info.st_mode):
            text = os.readlink(entry.path)
            resolved = os.path.realpath(entry.path)
            try:
                target = os.stat(resolved)
            except FileNotFoundError:
                refuse("dangling symlink in the base source: %s -> %s" % (rel, text))
            record = {"path": rel, "linkText": text}
            if stat.S_ISREG(target.st_mode):
                sha, size = copy_bytes(Path(resolved), dest, executable=bool(target.st_mode & 0o111))
                record.update(kind="file", sha256=sha, size=size,
                              target=os.path.relpath(resolved, base_real) if inside(resolved, base_real) else resolved)
            elif stat.S_ISDIR(target.st_mode):
                if not inside(resolved, base_real):
                    refuse("directory symlink leaves the base source: %s -> %s" % (rel, text))
                if resolved in chain:
                    refuse("directory symlink cycle at %s -> %s" % (rel, text))
                dest.mkdir(mode=0o755)
                materialize_tree(Path(resolved), dest, rel + "/", base_real, chain | {resolved}, excluded, links, False)
                record.update(kind="directory", target=os.path.relpath(resolved, base_real))
            else:
                refuse("symlink to a special file in the base source: %s" % rel)
            links.append(record)
        else:
            refuse("special file in the base source: %s" % rel)


def compose_snapshot(config, config_sha, base_value, layer_values, out_value, wrapper=WRAPPER):
    base = canonical_dir(base_value, "--base")
    out = new_path(out_value, "--out")
    if os.path.lexists(str(out)):
        refuse("--out already exists: %s" % out)
    overlay_root = canonical_dir(str(wrapper / config["composition"]["projectOverlays"]["root"]), "wrapper overlay root")
    layers = [canonical_dir(value, "--layer") for value in layer_values] + [overlay_root]
    named = {"--base": base, "--out": out, "wrapper": canonical_dir(str(wrapper), "wrapper root")}
    no_overlap(named)
    for layer in layers:
        if inside(layer, out) or inside(out, layer):
            refuse("--out overlaps layer %s" % layer)
    incoming = out.parent / (out.name + ".incoming")
    if os.path.lexists(str(incoming)):
        refuse("a previous incomplete composition exists: %s" % incoming)
    incoming.mkdir(mode=0o700)
    source = incoming / "source"
    source.mkdir(mode=0o755)

    say("materializing base %s (symlink bytes are copied and recorded)" % base)
    links = []
    excluded = set(config["composition"]["excludedTopLevel"])
    materialize_tree(base, source, "", str(base), {str(base)}, excluded, links, True)

    applied = []
    for delta in config["composition"]["deltas"]:
        rel = delta["path"]
        mismatches = []
        chosen = None
        for index, layer in enumerate(layers):
            candidate = layer / rel
            try:
                info = os.lstat(str(candidate))
            except FileNotFoundError:
                continue
            if not stat.S_ISREG(info.st_mode):
                mismatches.append("%s (not a regular file)" % candidate)
                continue
            sha, size = digest_file(candidate)
            if sha == delta["sha256"] and (delta["size"] is None or size == delta["size"]):
                chosen = (index, candidate, size)
                break
            mismatches.append("%s (%s, %d bytes)" % (candidate, sha, size))
        if chosen is None:
            refuse("no layer supplies the pinned bytes of %s (sha256 %s). Seen: %s"
                   % (rel, delta["sha256"], "; ".join(mismatches) or "none"))
        target = source / rel
        if os.path.lexists(str(target)):
            os.unlink(str(target))
        sha, size = copy_bytes(chosen[1], target)
        applied.append({"path": rel, "sha256": sha, "size": size, "step": delta["step"], "layer": str(layers[chosen[0]])})

    project_overlays = []
    for rel in config["composition"]["projectOverlays"]["paths"]:
        safe_relative(rel)
        target = source / rel
        if os.path.lexists(str(target)):
            os.unlink(str(target))
        sha, size = copy_bytes(overlay_root / rel, target)
        project_overlays.append({"path": rel, "projectPath": config["composition"]["projectOverlays"]["root"] + "/" + rel,
                                 "sha256": sha, "size": size})

    for forbidden in config["composition"]["forbiddenPaths"]:
        if os.path.lexists(str(source / forbidden["path"])):
            refuse("the composed source contains %s: %s" % (forbidden["path"], forbidden["why"]))

    make_read_only(source)
    entries = census(source)
    composition = {
        "schema": "zano-ios-sdk-snapshot",
        "version": 1,
        "producerConfigSha256": config_sha,
        "coreCommit": config["coreCommit"],
        "expectedVersion": config["expectedVersion"],
        "base": {"path": str(base), "excludedTopLevel": sorted(excluded)},
        "layers": [str(layer) for layer in layers],
        "deltas": applied,
        "projectOverlays": project_overlays,
        "materializedSymlinks": links,
        "census": census_digest(entries),
        "composedAtUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    write_new(incoming / "composition.json", (json.dumps(composition, indent=2) + "\n").encode("utf-8"), 0o444)
    publish(incoming, out)
    say("snapshot %s: %d files, %d materialized symlinks, census %s"
        % (out, composition["census"]["fileCount"], len(links), composition["census"]["sha256"]))
    return out


def admit_snapshot(snapshot, config, config_sha, wrapper=WRAPPER):
    composition_path = snapshot / "composition.json"
    composition = json.loads(open_text(composition_path))
    if composition.get("schema") != "zano-ios-sdk-snapshot" or composition.get("version") != 1:
        refuse("the snapshot has no zano-ios-sdk-snapshot composition record")
    if composition.get("producerConfigSha256") != config_sha:
        refuse("the snapshot was composed under a different producer configuration")
    if composition.get("expectedVersion") != config["expectedVersion"]:
        refuse("the snapshot names a different expectedVersion")
    top = sorted(os.listdir(str(snapshot)))
    if top != ["composition.json", "source"]:
        refuse("the snapshot holds unexpected entries: %s" % top)
    source = canonical_dir(str(snapshot / "source"), "snapshot source")
    say("verifying snapshot census (every file is re-hashed)")
    entries = census(source)
    if census_digest(entries) != composition["census"]:
        refuse("the snapshot source differs from its recorded census")
    by_path = {rel: (size, sha) for rel, size, sha in entries}
    pinned = [(d["path"], d["sha256"], d["size"]) for d in config["composition"]["deltas"]]
    recorded = [(d["path"], d["sha256"]) for d in composition["deltas"]]
    if recorded != [(p, s) for p, s, _ in pinned]:
        refuse("the snapshot applied a different delta set than the configuration pins")
    for rel, sha, size in pinned:
        have = by_path.get(rel)
        if have is None or have[1] != sha or (size is not None and have[0] != size):
            refuse("the snapshot does not carry the pinned bytes of %s" % rel)
    overlays = []
    for rel in config["composition"]["projectOverlays"]["paths"]:
        project_sha, project_size = digest_file(wrapper / config["composition"]["projectOverlays"]["root"] / rel)
        have = by_path.get(rel)
        if have is None or have != (project_size, project_sha):
            refuse("the snapshot Darwin overlay differs from this checkout: %s" % rel)
        overlays.append({"path": config["composition"]["projectOverlays"]["root"] + "/" + rel,
                         "sha256": project_sha, "size": project_size})
    for forbidden in config["composition"]["forbiddenPaths"]:
        if forbidden["path"] in by_path:
            refuse("the snapshot contains %s: %s" % (forbidden["path"], forbidden["why"]))
    check_source_version(source, config)
    return source, composition, overlays


def open_text(path):
    fd = open_regular(path)
    try:
        chunks = []
        while True:
            block = os.read(fd, CHUNK)
            if not block:
                break
            chunks.append(block)
        return b"".join(chunks).decode("utf-8")
    finally:
        os.close(fd)


def check_source_version(source, config):
    template = open_text(source / "src/version.h.in")
    values = dict(re.findall(r'^#define\s+(PROJECT_(?:MAJOR|MINOR)_VERSION|PROJECT_REVISION)\s+"([^"]*)"', template, re.M))
    number = re.search(r"^#define\s+PROJECT_VERSION_BUILD_NO\s+(\d+)", template, re.M)
    if len(values) != 3 or not number or '#define BUILD_COMMIT_ID "@VERSION@"' not in template:
        refuse("src/version.h.in does not have the expected version layout")
    project_version = "%s.%s.%s" % (values["PROJECT_MAJOR_VERSION"], values["PROJECT_MINOR_VERSION"], values["PROJECT_REVISION"])
    cmake_version = re.search(r'^set\(VERSION "([^"]+)"\)', open_text(source / "CMakeLists.txt"), re.M)
    sv = config["sourceVersion"]
    if project_version != sv["projectVersion"] or int(number.group(1)) != sv["buildNumber"] or \
            not cmake_version or cmake_version.group(1) != sv["cmakeVersion"]:
        refuse("the snapshot source version (%s.%s, VERSION %s) is not the configured one"
               % (project_version, number.group(1), cmake_version.group(1) if cmake_version else "?"))


def parse_version_tuple(text):
    return tuple(int(x) for x in text.split("."))


def tool(name):
    return run(["xcrun", "-f", name]).strip()


def first_line(text):
    return text.strip().splitlines()[0] if text.strip() else ""


def toolchain(config, cmake):
    record = {
        "xcodeSelect": run(["xcode-select", "-p"]).strip(),
        "xcodebuild": run(["xcodebuild", "-version"]).strip().splitlines(),
        "sdks": {},
        "tools": {},
        "generator": config["cmake"]["generator"],
        "deploymentTarget": config["deploymentTarget"],
    }
    for sdk, spec in config["sdks"].items():
        record["sdks"][sdk] = {
            "path": run(["xcrun", "--sdk", spec["sysroot"], "--show-sdk-path"]).strip(),
            "version": run(["xcrun", "--sdk", spec["sysroot"], "--show-sdk-version"]).strip(),
            "buildVersion": run(["xcrun", "--sdk", spec["sysroot"], "--show-sdk-build-version"]).strip(),
        }
    for name in ("clang", "clang++", "ar", "ranlib", "nm", "otool", "lipo", "make"):
        path = tool(name)
        real = os.path.realpath(path)
        record["tools"][name] = {"path": path, "sha256": digest_file(real)[0]}
    record["tools"]["clang"]["version"] = first_line(run([record["tools"]["clang"]["path"], "--version"]))
    cmake_real = os.path.realpath(cmake)
    cmake_version = first_line(run([cmake, "--version"]))
    found = re.search(r"cmake version (\d+(?:\.\d+)+)", cmake_version)
    if not found or parse_version_tuple(found.group(1))[:2] < parse_version_tuple(config["cmake"]["minimumVersion"]):
        refuse("CMake >= %s is required (%s)" % (config["cmake"]["minimumVersion"], cmake_version))
    record["tools"]["cmake"] = {"path": cmake, "realPath": cmake_real, "sha256": digest_file(cmake_real)[0], "version": cmake_version}
    return record


MEMBER_RE = re.compile(r"^(?:.*)\(([^()]+)\):$")


def macho_facts(archive):
    """Per archive member: build platform, minimum OS and bitcode presence, from otool -l."""
    text = run(["xcrun", "otool", "-l", str(archive)])
    members = {}
    current = None
    pending_version_min = False
    for line in text.splitlines():
        stripped = line.strip()
        member = MEMBER_RE.match(line)
        if member and not line.startswith(" "):
            current = members.setdefault(member.group(1), {"platforms": set(), "minos": set(), "bitcode": False})
            pending_version_min = False
            continue
        if current is None:
            continue
        if stripped.startswith("cmd "):
            pending_version_min = stripped == "cmd LC_VERSION_MIN_IPHONEOS"
            if pending_version_min:
                current["platforms"].add("2")
        elif stripped.startswith("platform "):
            current["platforms"].add(stripped.split()[1])
        elif stripped.startswith("minos "):
            current["minos"].add(stripped.split()[1])
        elif stripped.startswith("version ") and pending_version_min:
            current["minos"].add(stripped.split()[1])
        elif stripped in ("sectname __bitcode", "segname __LLVM"):
            current["bitcode"] = True
    if not members:
        refuse("otool found no Mach-O members in %s" % archive)
    return members


def check_archive(archive, spec, deployment, exact_minos, refuse_bitcode):
    archs = run(["xcrun", "lipo", "-archs", str(archive)]).split()
    if archs != [spec["arch"]]:
        refuse("%s holds architectures %s, expected exactly %s" % (archive, archs, spec["arch"]))
    accepted = {str(spec["machoPlatform"]), spec["machoPlatformName"]}
    members = macho_facts(archive)
    target = parse_version_tuple(deployment)
    bitcode_members = 0
    for name, facts in members.items():
        if not facts["platforms"] or not facts["platforms"] <= accepted:
            refuse("%s(%s) is built for platform %s, expected %s" % (archive, name, sorted(facts["platforms"]) or "unknown", spec["machoPlatformName"]))
        if len(facts["minos"]) != 1:
            refuse("%s(%s) has no single minimum OS version" % (archive, name))
        minos = parse_version_tuple(next(iter(facts["minos"])))
        if (exact_minos and minos != target) or minos > target:
            refuse("%s(%s) minimum OS %s does not fit deployment target %s" % (archive, name, ".".join(map(str, minos)), deployment))
        if facts["bitcode"]:
            bitcode_members += 1
    if refuse_bitcode and bitcode_members:
        refuse("%s still embeds bitcode in %d members" % (archive, bitcode_members))
    return {"arch": spec["arch"], "platform": spec["machoPlatformName"], "members": len(members), "bitcodeMembers": bitcode_members}


def check_wallet_archive(archive, config):
    members = run(["xcrun", "ar", "-t", str(archive)]).split()
    for unit in config["requiredCompiledUnits"]:
        name = os.path.basename(unit) + ".o"
        if members.count(name) != 1:
            refuse("%s holds %d copies of %s (expected exactly 1)" % (archive, members.count(name), name))
    symbols = run(["xcrun", "nm", "-g", "-U", "-j", str(archive)])
    missing = []
    for name in config["requiredWalletSymbols"]:
        fragment = "14native_session12file_session%d%s" % (len(name), name)
        if fragment not in symbols:
            missing.append(name)
    if missing:
        refuse("%s does not define tools::native_session::file_session::%s" % (archive, ", ".join(missing)))


def check_compile_commands(build, source, config, sdk_path):
    commands = json.loads(open_text(build / "compile_commands.json"))
    sdk_real = os.path.realpath(sdk_path)
    for unit in config["requiredCompiledUnits"]:
        wanted = os.path.realpath(str(source / unit))
        found = [c for c in commands if os.path.realpath(os.path.join(c.get("directory", ""), c["file"])) == wanted]
        if len(found) != 1:
            refuse("%s is configured %d times (expected exactly 1)" % (unit, len(found)))
        line = found[0].get("command") or " ".join(found[0].get("arguments", []))
        for flag in config["requiredCompileDefinitions"] + ["-fembed-bitcode=off"]:
            if flag not in line.split():
                refuse("%s is compiled without %s" % (unit, flag))
        sysroot = re.search(r"-isysroot\s+(\S+)", line)
        if not sysroot or os.path.realpath(sysroot.group(1)) != sdk_real:
            refuse("%s is not compiled against %s" % (unit, sdk_path))
        if "-arch arm64" not in line and "-target arm64-" not in line:
            refuse("%s is not compiled for arm64" % unit)


def built_version(build):
    text = open_text(build / "version/version.h")
    values = dict(re.findall(r'^#define\s+(\w+)\s+"([^"]*)"', text, re.M))
    number = re.search(r"^#define PROJECT_VERSION_BUILD_NO\s+(\d+)", text, re.M)
    if not number or "BUILD_COMMIT_ID" not in values:
        refuse("the generated version.h has no build identity")
    return "%s.%s.%s.%s[%s]" % (values["PROJECT_MAJOR_VERSION"], values["PROJECT_MINOR_VERSION"],
                                values["PROJECT_REVISION"], number.group(1), values["BUILD_COMMIT_ID"])


def header_closure(config):
    """The consumer include-path set, owned by this library configuration (headers.closurePaths)."""
    paths = config["headers"]["closurePaths"]
    if not paths or paths != sorted(set(paths)):
        refuse("headers.closurePaths must be a non-empty sorted list of distinct paths")
    for rel in paths:
        safe_relative(rel)
    return list(paths)


# Darwin reading of the Android closure. That closure is the file set the
# Android install shipped (OpenSSL 3.1.8 source include tree, flat wallet
# install), not a parsed include graph. Exactly three sourced differences apply
# to the Apple stage; every other path keeps its existing resolution and refusal.
#
# 1. OpenSSL __DECC_INCLUDE_{PROLOGUE,EPILOGUE}.H. No OpenSSL or Zano header
#    names them in a directive: HP C/C++ on OpenVMS loads them implicitly around
#    every header of their directory, as their own text says. Apple clang has
#    no such mechanism, and OpenSSL `make install_dev` (unix-Makefile.tmpl, loop
#    over include/openssl/*.h) never installs them. Not part of the Darwin
#    closure; if a slice carries one, it must be the upstream VMS-only file.
DARWIN_VMS_IMPLICIT_HEADERS = (
    "crypto/__DECC_INCLUDE_EPILOGUE.H",
    "crypto/__DECC_INCLUDE_PROLOGUE.H",
    "internal/__DECC_INCLUDE_EPILOGUE.H",
    "internal/__DECC_INCLUDE_PROLOGUE.H",
    "openssl/__DECC_INCLUDE_EPILOGUE.H",
    "openssl/__DECC_INCLUDE_PROLOGUE.H",
)


VMS_IMPLICIT_MARKER = re.compile(rb"This file is only used by HP C(?:/C\+\+)? on VMS, and is included automatically")


# 2. openssl/asn1_mac.h: in the Android 3.1.8 install a 398-byte stub whose
#    only directive is `#error "This file is obsolete; ..."`, so no compiling
#    consumer includes it; OpenSSL 3.5.9 no longer ships it. Staged when every
#    slice has it, left out only when no slice has it.
DARWIN_RETIRED_OPENSSL_HEADERS = ("openssl/asn1_mac.h",)


# 3. plain_wallet_api.h: the Android branch of src/CMakeLists.txt installs
#    `file(GLOB wallet/*.h)` flat into include/; the composed source keeps it in
#    src/wallet/. The podspec and ZNNativeRuntime.mm include it as
#    include/plain_wallet_api.h.
DARWIN_FLATTENED_SOURCE_HEADERS = {"plain_wallet_api.h": "src/wallet/plain_wallet_api.h"}


# 4. The public OpenSSL header set is the slice's own install, not the Android
#    3.1.8 path list. OpenSSL `make install_dev` (unix-Makefile.tmpl) installs
#    every $(SRCDIR)/include/openssl/*.h and $(BLDDIR)/include/openssl/*.h flat
#    into include/openssl; a newer release adds public headers its own public
#    headers include (3.5.9 core_dispatch.h includes openssl/indicator.h, absent
#    from 3.1.8). So each slice stages exactly the admitted include/openssl tree
#    it carries: flat *.h files, generated ones included, measured per slice.
#    The closure's openssl/ paths still must be present in every slice (or be
#    corrections 1/2); crypto/ and internal/ keep the closure path list.
OPENSSL_PUBLIC_PREFIX = "openssl/"


def openssl_public_tree(deps, sdk, source, config):
    """Paths openssl/<name>.h of the admitted install_dev public tree of one slice.

    Refuses a missing or empty tree, subdirectories, links, any file that is not
    an install_dev *.h (other than the exact VMS-only names, which the closure
    loop verifies and excludes) and a name the composed source would shadow.
    """
    root = deps / "openssl" / sdk / "include" / "openssl"
    if not os.path.lexists(str(root)):
        refuse("the %s OpenSSL include tree has no public include/openssl directory" % sdk)
    root = canonical_dir(str(root), "%s OpenSSL public include" % sdk)
    paths = []
    for rel, _size, _sha in census(root):
        full = OPENSSL_PUBLIC_PREFIX + rel
        if full in DARWIN_VMS_IMPLICIT_HEADERS:
            continue
        if "/" in rel or not rel.endswith(".h"):
            refuse("the %s OpenSSL public include tree holds %s, which `make install_dev` does not install" % (sdk, full))
        for search in config["headers"]["sourceSearch"]:
            if os.path.lexists(str(source / search / full)):
                refuse("%s resolves both through the source search (%s/%s) and the %s OpenSSL install" % (full, search, full, sdk))
        paths.append(full)
    if not paths:
        refuse("the %s OpenSSL public include tree holds no headers" % sdk)
    return paths


def resolve_header_closure(config, source, deps, closure=None):
    """Where each closure path's Darwin bytes come from; refuses anything unresolved.

    Returns {"include": [(src, rel, origin)], "openssl": {sdk: [(src, rel)]},
    "excluded": [{"path", "reason"}]}. Nothing is copied here.
    """
    closure = header_closure(config) if closure is None else list(closure)
    listed = set(closure)
    corrections = set(DARWIN_VMS_IMPLICIT_HEADERS) | set(DARWIN_RETIRED_OPENSSL_HEADERS) | set(DARWIN_FLATTENED_SOURCE_HEADERS)
    for rel in sorted(corrections - listed):
        refuse("the Darwin closure correction names %s, which the header closure does not list" % rel)
    sdks = list(config["sdks"])
    prefixes = tuple(config["headers"]["opensslPrefixes"])
    plan = {"include": [], "openssl": {sdk: [] for sdk in sdks}, "excluded": []}
    # Correction 4: every slice independently carries its own public tree.
    public = {sdk: openssl_public_tree(deps, sdk, source, config) for sdk in sdks}
    for sdk in sdks:
        plan["openssl"][sdk] += [(deps / "openssl" / sdk / "include" / rel, rel) for rel in public[sdk]]
    for rel in closure:
        if rel in DARWIN_VMS_IMPLICIT_HEADERS:
            for sdk in sdks:
                candidate = deps / "openssl" / sdk / "include" / rel
                if os.path.lexists(str(candidate)):
                    fd = open_regular(candidate)
                    with os.fdopen(fd, "rb") as handle:
                        if not VMS_IMPLICIT_MARKER.search(handle.read()):
                            refuse("the %s OpenSSL include tree holds %s, which is not the upstream VMS-only header" % (sdk, rel))
            plan["excluded"].append({"path": rel, "reason": "vms-implicit-include"})
            continue
        if rel.startswith(config["headers"]["boostPrefix"]):
            plan["include"].append((deps / "boost/include" / rel, rel, "input:boost"))
            continue
        resolved = None
        for search in config["headers"]["sourceSearch"]:
            candidate = source / search / rel
            if os.path.lexists(str(candidate)):
                resolved = (candidate, "source:%s/%s" % (search, rel))
                break
        if rel in DARWIN_FLATTENED_SOURCE_HEADERS:
            if resolved:
                refuse("%s resolves both through the source search (%s) and as a flattened wallet header" % (rel, resolved[1]))
            flat = DARWIN_FLATTENED_SOURCE_HEADERS[rel]
            candidate = source / flat
            if not os.path.lexists(str(candidate)):
                refuse("the composed source lacks %s, the install source of %s" % (flat, rel))
            resolved = (candidate, "source:" + flat)
        if resolved:
            plan["include"].append((resolved[0], rel, resolved[1]))
        elif rel.startswith(prefixes):
            present = [sdk for sdk in sdks if os.path.lexists(str(deps / "openssl" / sdk / "include" / rel))]
            if rel in DARWIN_RETIRED_OPENSSL_HEADERS and not present:
                plan["excluded"].append({"path": rel, "reason": "retired-from-openssl-slice"})
                continue
            for sdk in sdks:
                if sdk not in present:
                    refuse("the %s OpenSSL include tree lacks %s" % (sdk, rel))
                if rel.startswith(OPENSSL_PUBLIC_PREFIX):
                    if rel not in public[sdk]:
                        refuse("the %s OpenSSL public include tree does not install %s" % (sdk, rel))
                    continue  # already staged from that slice's public tree
                plan["openssl"][sdk].append((deps / "openssl" / sdk / "include" / rel, rel))
        else:
            refuse("header %s resolves to no composed source, Boost or OpenSSL input" % rel)
    for sdk in sdks:
        plan["openssl"][sdk].sort(key=lambda row: row[1])
    # An exclusion holds only while nothing the stage carries names it (any case:
    # Apple file systems are case-insensitive by default).
    names = {e["path"].rsplit("/", 1)[-1].lower().encode("ascii"): e["path"] for e in plan["excluded"]}
    if names:
        staged = [src for src, _rel, _origin in plan["include"]]
        for sdk in sdks:
            staged += [src for src, _rel in plan["openssl"][sdk]]
        for src in staged:
            fd = open_regular(src)
            with os.fdopen(fd, "rb") as handle:
                text = handle.read().lower()
            for name, rel in names.items():
                if name in text:
                    refuse("%s names %s, which the Darwin header closure leaves out" % (src, rel))
    return plan


def planned_header_rows(plan, sdks):
    """{stage path: (sha256, size)} the packaging plan stages, measured from its sources now."""
    rows = {}
    for src, rel, _origin in plan["include"]:
        rows["include/" + rel] = digest_file(src)
    for sdk in sdks:
        for src, rel in plan["openssl"][sdk]:
            rows["openssl/%s/include/%s" % (sdk, rel)] = digest_file(src)
    return rows


def check_reused_headers(lock, plan, sdks):
    """An existing stage is reused only if its header rows are exactly what the current plan stages."""
    recorded = {}
    for row in list(lock.get("headers") or []) + [r for sdk in sdks for r in (lock.get("opensslHeaders") or {}).get(sdk) or []]:
        recorded[row["path"]] = (row["sha256"], row["size"])
    wanted = planned_header_rows(plan, sdks)
    if recorded != wanted or lock.get("headerClosureExclusions") != plan["excluded"]:
        missing = sorted(set(wanted) - set(recorded))
        extra = sorted(set(recorded) - set(wanted))
        changed = sorted(p for p in set(wanted) & set(recorded) if wanted[p] != recorded[p])
        refuse("the existing stage's headers differ from the current header closure (missing %s, extra %s, changed %s); "
               "choose a new ZANO_IOS_NATIVE_STAGE" % (missing[:5], extra[:5], changed[:5]))


def build_env():
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin:/usr/sbin:/sbin"), "LANG": "C", "LC_ALL": "C"}
    for key in ("HOME", "TMPDIR", "DEVELOPER_DIR", "USER"):
        if os.environ.get(key):
            env[key] = os.environ[key]
    stripped = sorted(k for k in STRIPPED_ENV if k in os.environ)
    return env, stripped


def configure_argv(cmake, config, sdk, spec, source, build, deps, label):
    ossl = deps / "openssl" / sdk
    cache = dict(config["cmake"]["cache"])
    cache.update({
        "CMAKE_OSX_SYSROOT": spec["sysroot"],
        "CMAKE_OSX_ARCHITECTURES": spec["arch"],
        "CMAKE_OSX_DEPLOYMENT_TARGET": config["deploymentTarget"],
        "CMAKE_INSTALL_PREFIX": str(build) + "-unused-install",
        "COMMIT": label,
        "Boost_INCLUDE_DIRS": str(deps / "boost/include"),
        "OPENSSL_ROOT_DIR": str(ossl),
        "OPENSSL_INCLUDE_DIR": str(ossl / "include"),
        "OPENSSL_CRYPTO_LIBRARY": str(ossl / "lib/libcrypto.a"),
        "OPENSSL_SSL_LIBRARY": str(ossl / "lib/libssl.a"),
    })
    argv = [cmake, "-S", str(source), "-B", str(build), "-G", config["cmake"]["generator"]]
    argv += ["-D%s=%s" % (key, cache[key]) for key in sorted(cache)]
    return argv


def check_snapshot_census(snapshot):
    composition = json.loads(open_text(snapshot / "composition.json"))
    if sorted(os.listdir(str(snapshot))) != ["composition.json", "source"]:
        refuse("the snapshot holds unexpected entries")
    if census_digest(census(snapshot / "source")) != composition.get("census"):
        refuse("the snapshot source differs from its recorded census")
    return composition


def build_sdk(config, sdk, spec, source, deps, work, logs, cmake, tools, env, jobs):
    """Configures and builds the SDK targets of one slice from the admitted composed source and
    checks the result: compile commands, built version, archive platform/deployment/bitcode facts
    and wallet symbols. Returns ({"archives", "facts", "version"}, seconds)."""
    build = work / ("build-" + sdk)
    log = logs / ("%s.log" % sdk)
    start = time.monotonic()
    say("configuring %s (CMake, %s)" % (sdk, config["cmake"]["generator"]))
    run(configure_argv(cmake, config, sdk, spec, source, build, deps, config["versionCommitLabel"]),
        log=log, cwd=str(work), env=env, timeout=1800)
    check_compile_commands(build, source, config, tools["sdks"][sdk]["path"])
    say("building %s targets %s with %d jobs (this takes a while)" % (sdk, " ".join(config["cmake"]["targets"]), jobs))
    run([cmake, "--build", str(build), "--target"] + config["cmake"]["targets"] + ["--parallel", str(jobs)],
        log=log, cwd=str(work), env=env, timeout=4 * 3600)
    version = built_version(build)
    if version != config["expectedVersion"]:
        refuse("%s built version %s, expected %s" % (sdk, version, config["expectedVersion"]))
    archives = {}
    for role, rel in config["cmake"]["archives"].items():
        path = build / rel
        if not os.path.lexists(str(path)):
            refuse("%s build did not produce %s" % (sdk, rel))
        archives[role] = path
    facts = {role: check_archive(path, spec, config["deploymentTarget"], True, True) for role, path in archives.items()}
    check_wallet_archive(archives["zano-wallet"], config)
    return {"archives": archives, "facts": facts, "version": version}, round(time.monotonic() - start, 1)


# --------------------------------------------------------------------------
# source closure (mobile/ios/closure.json) through the pinned core
# --------------------------------------------------------------------------

def git_bytes(repo, *args, data=None):
    proc = subprocess.run(["git", "-C", str(repo), *args], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        refuse("git %s failed in %s" % (args[0], repo))
    return proc.stdout


def gitlink_at(repo, rev, path):
    fields = git_bytes(repo, "ls-tree", rev, "--", path).decode().split()
    return fields[2] if len(fields) >= 3 and fields[1] == "commit" else None


def read_objects(repo, specs):
    """{spec: bytes} for git object specs (<rev>:<path>) read in one cat-file --batch."""
    out = git_bytes(repo, "cat-file", "--batch", data=("".join(s + "\n" for s in specs)).encode())
    found, at = {}, 0
    for spec in specs:
        end = out.index(b"\n", at)
        header = out[at:end].split()
        if len(header) != 3 or header[1] != b"blob":
            refuse("%s holds no blob %s" % (repo, spec))
        size = int(header[2])
        found[spec] = out[end + 1:end + 1 + size]
        at = end + 1 + size + 1
    return found


def admit_closure(config, config_sha, wrapper=WRAPPER, closure=None, census=None):
    """The wrapper's iOS closure for this configuration: the manifest's Apple composition commit,
    the pinned closure bytes, the core's pinned submodule commits and (when given) the census."""
    manifest = json.loads(open_text(wrapper / "mobile" / "zano-mobile-sdk.json"))
    apple = manifest["compositions"][APPLE_COMPOSITION]
    if apple.get("producerConfigSha256") != config_sha:
        refuse("the wrapper's Apple composition names another producer configuration than %s" % config_sha)
    if closure is None:
        if digest_file(wrapper / "mobile" / "ios" / "closure.json")[0] != apple["closure"]["sha256"]:
            refuse("mobile/ios/closure.json is not the closure the wrapper manifest pins")
        closure = json.loads(open_text(wrapper / "mobile" / "ios" / "closure.json"))
    if closure.get("schema") != "zano-ios-sdk-closure" or closure.get("version") != 1 or \
            closure.get("sourceCommit") != apple["sourceCommit"] or (census is not None and closure.get("census") != census):
        refuse("the wrapper closure is not the pinned Apple composition and census")
    core = wrapper / "Zano"
    for link, commit in sorted(closure["submodules"].items()):
        if gitlink_at(core, closure["sourceCommit"], link) != commit:
            refuse("core submodule %s is not pinned to %s at %s" % (link, commit, closure["sourceCommit"]))
    return {"wrapper": wrapper, "core": core, "closure": closure}


def materialize_closure(ctx, dest):
    """Writes every closure file with its pinned bytes and packet mode under dest (new)."""
    closure, core, wrapper = ctx["closure"], ctx["core"], ctx["wrapper"]
    captured = set(closure["captured"]["paths"])
    batches, rows = {}, []
    for row in closure["files"]:
        rel = safe_relative(row["path"])
        if row["from"] == "core":
            batches.setdefault(str(core), []).append("%s:%s" % (closure["sourceCommit"], rel))
        elif row["from"] == "submodule":
            link = next((l for l in closure["submodules"] if rel.startswith(l + "/")), None)
            if link is None:
                refuse("closure submodule path outside every pinned submodule: %s" % rel)
            batches.setdefault(str(core / link), []).append("%s:%s" % (closure["submodules"][link], rel[len(link) + 1:]))
        elif row["from"] != "captured" or rel not in captured:
            refuse("closure path has no admitted resolution: %s" % rel)
        rows.append((rel, row))
    data = {}
    for repo, specs in batches.items():
        for spec, blob in read_objects(repo, specs).items():
            data[(repo, spec)] = blob
    for rel, row in rows:
        if row["from"] == "core":
            blob = data[(str(core), "%s:%s" % (closure["sourceCommit"], rel))]
        elif row["from"] == "submodule":
            link = next(l for l in closure["submodules"] if rel.startswith(l + "/"))
            blob = data[(str(core / link), "%s:%s" % (closure["submodules"][link], rel[len(link) + 1:]))]
        else:
            path = wrapper / closure["captured"]["root"] / rel
            if not stat.S_ISREG(os.lstat(str(path)).st_mode):
                refuse("captured input is not a regular file: %s" % rel)
            blob = path.read_bytes()
        if hashlib.sha256(blob).hexdigest() != row["sha256"] or len(blob) != row["size"]:
            refuse("%s does not resolve to its closure pin" % rel)
        target = dest / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        write_new(target, blob, 0o755 if row["executable"] else 0o644)


def snapshot_from_closure(config, config_sha, scratch_value, wrapper=WRAPPER, closure=None):
    """A new composed snapshot (composition.json + source) of the closure under scratch, admitted
    with admit_snapshot. Returns (snapshot, admitted source, composition, overlays, closure ctx)."""
    ctx = admit_closure(config, config_sha, wrapper, closure)
    scratch = new_path(scratch_value, "--scratch")
    if os.path.lexists(str(scratch)):
        refuse("--scratch must be a new directory: %s exists" % scratch)
    if inside(scratch, wrapper) or inside(wrapper, scratch):
        refuse("--scratch overlaps the wrapper")
    scratch.mkdir(mode=0o700)
    snapshot = scratch / "snapshot"
    snapshot.mkdir(mode=0o755)
    materialize_closure(ctx, snapshot / "source")
    entries = census(snapshot / "source")
    if census_digest(entries) != ctx["closure"]["census"]:
        refuse("the materialized closure is not its pinned census")
    root = config["composition"]["projectOverlays"]["root"]
    by_path = {rel: (size, sha) for rel, size, sha in entries}
    record = {
        "schema": "zano-ios-sdk-snapshot", "version": 1, "producerConfigSha256": config_sha,
        "coreCommit": config["coreCommit"], "expectedVersion": config["expectedVersion"],
        "base": {"path": "closure:" + ctx["closure"]["sourceCommit"], "excludedTopLevel": sorted(config["composition"]["excludedTopLevel"])},
        "layers": [],
        "deltas": [{"path": d["path"], "sha256": by_path.get(d["path"], (0, ""))[1], "size": by_path.get(d["path"], (0, ""))[0],
                    "step": d["step"], "layer": "closure"} for d in config["composition"]["deltas"]],
        "projectOverlays": [{"path": rel, "projectPath": root + "/" + rel, "sha256": by_path.get(rel, (0, ""))[1],
                             "size": by_path.get(rel, (0, ""))[0]} for rel in config["composition"]["projectOverlays"]["paths"]],
        "materializedSymlinks": [],
        "census": census_digest(entries),
        "composedAtUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    write_new(snapshot / "composition.json", (json.dumps(record, indent=2) + "\n").encode("utf-8"), 0o444)
    make_read_only(snapshot)
    source, composition, overlays = admit_snapshot(snapshot, config, config_sha, wrapper)
    return snapshot, source, composition, overlays, ctx


def source_header_plan(config, source):
    """Where each header-closure path comes from without any dependency root: the composed source
    (search roots or the flattened wallet header), Boost, an OpenSSL slice, or the Darwin VMS-only
    exclusion. Refuses a path none of these covers and a required header outside the closure."""
    closure = header_closure(config)
    for rel in config["headers"]["required"]:
        if rel not in closure:
            refuse("required header %s is outside the header closure" % rel)
    prefixes = tuple(config["headers"]["opensslPrefixes"])
    plan = {"source": [], "boost": [], "openssl": [], "excluded": []}
    for rel in closure:
        if rel in DARWIN_VMS_IMPLICIT_HEADERS:
            plan["excluded"].append(rel)
            continue
        if rel.startswith(config["headers"]["boostPrefix"]):
            plan["boost"].append(rel)
            continue
        found = [s for s in config["headers"]["sourceSearch"] if os.path.lexists(str(source / s / rel))]
        if rel in DARWIN_FLATTENED_SOURCE_HEADERS:
            if found or not os.path.lexists(str(source / DARWIN_FLATTENED_SOURCE_HEADERS[rel])):
                refuse("the flattened wallet header %s does not resolve exactly once" % rel)
            plan["source"].append(rel)
        elif found:
            plan["source"].append(rel)
        elif rel.startswith(prefixes):
            plan["openssl"].append(rel)
        else:
            refuse("header %s resolves to no composed source, Boost or OpenSSL input" % rel)
    return plan


INTERFACE = tuple(name for name in (
    "WRAPPER", "CONFIG_PATH", "CHUNK", "STRIPPED_ENV", "Refusal", "refuse", "say", "open_regular", "digest_file",
    "copy_bytes", "write_new", "inside", "canonical_dir", "new_path", "no_overlap", "census", "census_digest",
    "make_read_only", "publish", "load_config", "safe_relative", "run", "LOG_TAIL_BYTES", "LOG_TAIL_LINES",
    "LOG_DIAGNOSTIC_TOTAL_BYTES", "materialize_tree",
    "compose_snapshot", "admit_snapshot", "open_text", "check_source_version", "parse_version_tuple", "tool",
    "first_line", "toolchain", "macho_facts", "check_archive", "check_wallet_archive", "check_compile_commands",
    "built_version", "header_closure", "DARWIN_VMS_IMPLICIT_HEADERS", "VMS_IMPLICIT_MARKER",
    "DARWIN_RETIRED_OPENSSL_HEADERS", "DARWIN_FLATTENED_SOURCE_HEADERS", "OPENSSL_PUBLIC_PREFIX",
    "openssl_public_tree", "resolve_header_closure", "planned_header_rows", "check_reused_headers", "build_env",
    "configure_argv", "check_snapshot_census", "build_sdk", "git_bytes", "gitlink_at", "read_objects",
    "admit_closure", "materialize_closure", "snapshot_from_closure", "source_header_plan"))


def cmd_plan(args):
    config, config_sha = load_config()
    snapshot, source, composition, overlays, ctx = snapshot_from_closure(config, config_sha, args.scratch)
    plan = source_header_plan(config, source)
    print(json.dumps({
        "producerConfigSha256": config_sha, "expectedVersion": config["expectedVersion"],
        "sourceCommit": ctx["closure"]["sourceCommit"], "submodules": ctx["closure"]["submodules"],
        "snapshot": str(snapshot), "census": composition["census"], "deltas": len(composition["deltas"]),
        "overlays": overlays, "sdks": sorted(config["sdks"]), "targets": config["cmake"]["targets"],
        "archives": config["cmake"]["archives"],
        "headerClosure": {k: len(v) for k, v in plan.items()},
        "build": "not run: build_sdk needs macOS with Xcode and the Boost/OpenSSL dependency slices",
    }, indent=1, sort_keys=True))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    plan = sub.add_parser("plan", help="materialize and admit the closure snapshot, resolve headers, print the plan")
    plan.add_argument("--scratch", required=True)
    args = parser.parse_args(argv)
    try:
        return cmd_plan(args)
    except Refusal as error:
        print("[zano-ios-sdk-producer] REFUSED: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

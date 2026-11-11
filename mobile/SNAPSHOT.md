# Maintained snapshot profile

The `Zano` submodule points at the maintained mobile SDK source snapshot. That snapshot is a single root commit, `428edd06ee3691b3b51a270f85a0d25d859b81bc` (tree `beb496b8753ed8f08e885b9bb52861fe0b29a51f`, no parent), on branch `feat/mobile-publishable-snapshot-2026-11-11`. It is a local commit and is not on the hyle-team/zano remote yet.

`zano-mobile-sdk-snapshot.json` pins that root. It records:

- the tree, a census of every file in it, and the four submodule commits
- the bytes of the SDK composition
- the expected SDK version
- the exact inputs and scripts of both producers

`check_core_pin.py --profile snapshot` verifies all of it against the core objects and this repository's files.

## Two profiles

Every tool takes `--profile legacy` or `--profile snapshot`. There is no default.

| | legacy | snapshot |
|---|---|---|
| Manifest | `zano-mobile-sdk.json` | `zano-mobile-sdk-snapshot.json` |
| Android inputs | `android/inputs.json` | `android/inputs-snapshot.json` |
| iOS configuration | `ios/sdk-producer.json` | `ios/sdk-producer-snapshot.json` |
| iOS closure | `ios/closure.json` | `ios/closure-snapshot.json` |
| Core commits needed | the original lineage (299bf172 to e90a4e18) | only the snapshot root |

The legacy files are kept unchanged for consumers that still pin the original lineage. The snapshot profile lists the old commit ids under `historicalReferences` as provenance only. It never resolves them, and they are not ancestry of the root.

## SDK version identity

Both snapshot producers configure the core with `REFS` empty, `GIT=OFF`, `COMMIT_ID_IN_VERSION=ON` and `COMMIT` set to the root commit id. That is the core's existing COMMIT route in `CMakeLists.txt`, the one it uses for source archives. With `src/version.h.in` it gives:

```
2.2.1.506[1.0-g428edd06ee3691b3b51a270f85a0d25d859b81bc]
```

This string identifies the source a build came from. It does not mean a build matches any earlier artifact, and it does not imply ancestry.

The snapshot profile does not use the normal Git label. Without `COMMIT`, `src/version.cmake` builds the label from the short hash, the branch name, a dirty marker and a `testnet-` prefix. That result depends on the state of the checkout. The iOS producer also compiles a materialized copy of the sources, which is not a Git work tree. The producers never add branch or dirty suffixes of their own.

`TESTNET=ON` selects the testnet build through the `-DTESTNET` compile definition, which the iOS producer checks in each compile command. It does not appear in the version string on this route.

`test_snapshot_version.py` checks this with host CMake. It runs the root's own version block and `src/version.h.in` with the identity options the producers plan, then reads the generated `version.h` with both producers' checkers. It also checks that the legacy label is rejected and that the TESTNET setting leaves the header unchanged. It configures only and compiles nothing.

## Legacy evidence stays separate

The legacy version `2.2.1.506[1.0-g299bf172e8428042919b48bfa1cedfcd9ede139a-native-snapshot-compat-v1]` belongs to the original lineage only. So do the observed 308-entry Android input set (287 headers, 15 dependencies, 6 built outputs) and its publisher lock `567e3664…`. They are not inputs, expected values or proof for anything built from the snapshot.

## Status

The profile is unqualified. Nothing has been built from it, and it records no output digests.

The iOS closure resolves byte for byte to the same 824 files as the legacy closure. The Android composition is new: it builds the full root tree, which includes the four project overlays that the legacy Android composition left out.

Next steps:

1. QA runs both producers from the snapshot profile and measures their outputs.
2. An owner review adopts the measured results.

Consuming apps keep their current library pins until then.

## Checks

The `Zano` checkout must be at the root, with `contrib/jwt-cpp` and `contrib/miniupnp` initialized. The CMake proof needs host CMake 3.16 or newer.

```
python3 -I mobile/check_core_pin.py --profile snapshot --core-git Zano
python3 -I mobile/test_snapshot_version.py -v
python3 -I mobile/android/produce_android.py plan --profile snapshot --source Zano
python3 -I mobile/ios/sdk_producer.py plan --profile snapshot --scratch /new/absolute/dir
```

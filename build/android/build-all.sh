#!/bin/bash

SCRIPT_ROOT="$(realpath "$(dirname "$0")")"

"${SCRIPT_ROOT}/build.sh" arm64-v8a
"${SCRIPT_ROOT}/build.sh" armeabi-v7a
"${SCRIPT_ROOT}/build.sh" x86
"${SCRIPT_ROOT}/build.sh" x86_64

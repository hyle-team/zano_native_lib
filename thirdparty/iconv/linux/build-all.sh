#!/bin/bash

SCRIPT_ROOT="$(realpath "$(dirname "$0")")"

"${SCRIPT_ROOT}/build.sh" x86_64
"${SCRIPT_ROOT}/build.sh" arm64

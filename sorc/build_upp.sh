#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/.." && pwd -P)

# Check WAFS/exec folder exists
if [[ ! -d "${DIR_ROOT}/exec" ]]; then
  mkdir -p "${DIR_ROOT}/exec"
fi

# Build upp executable file
module reset
source "${DIR_ROOT}/versions/build.ver"

cd "${DIR_ROOT}/sorc/wafs_upp.fd/tests"
./compile_upp.sh -g

# Copy upp to WAFS/exec
rm -rf "${DIR_ROOT}/exec/wafs_upp.x"
cp "${DIR_ROOT}/sorc/wafs_upp.fd/exec/upp.x" "${DIR_ROOT}/exec/wafs_upp.x"

exit

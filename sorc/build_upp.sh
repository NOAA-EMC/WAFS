#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

# User Options
BUILD_TYPE=${BUILD_TYPE:-"Release"}

# Build upp.x
cd "${DIR_ROOT}/sorc/upp.fd/tests"

_opts="-g "  # Always build with GTG ON
_opts+="-p ${DIR_ROOT}/sorc/install/upp "  # Install prefix
[[ "${BUILD_TYPE:-}" == "Debug" ]] && _opts+="-d "
[[ "${BUILD_VERBOSE:-}" =~ [yYtT] ]] && _opts+="-v "

export BUILD_DIR="${DIR_ROOT}/sorc/build/upp"

BUILD_JOBS=${BUILD_JOBS:-8} ./compile_upp.sh ${_opts}

# Check WAFS/exec folder exists
if [[ ! -d "${DIR_ROOT}/exec" ]]; then
  mkdir -p "${DIR_ROOT}/exec"
fi

# Copy upp.x to WAFS/exec
rm -rf "${DIR_ROOT}/exec/upp.x"
cp "${DIR_ROOT}/sorc/install/upp/bin/upp.x" "${DIR_ROOT}/exec/upp.x"

exit

#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

# User Options
BUILD_TYPE=${BUILD_TYPE:-"Release"}
CMAKE_OPTS=${CMAKE_OPTS:-}
COMPILER=${COMPILER:-"intel"}
BUILD_DIR=${BUILD_DIR:-"${DIR_ROOT}/build"}
INSTALL_PREFIX=${INSTALL_PREFIX:-"${DIR_ROOT}/install"}

cd $DIR_ROOT/sorc/upp.fd/tests

_opts=""
[[ "${BUILD_TYPE:-}" == "Debug" ]] && _opts+="-d "
[[ "${BUILD_VERBOSE:-}" ~= [yYtT] ]] && _opts+="-v "

# Check final exec folder exists
if [[ ! -d "${DIR_ROOT}/exec" ]]; then
  mkdir -p "${DIR_ROOT}/exec"
fi

BUILD_JOBS=${BUILD_JOBS:-8} ./compile_upp.sh ${_opts}

exit

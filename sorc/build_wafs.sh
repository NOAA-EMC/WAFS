#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

# User Options
BUILD_TYPE=${BUILD_TYPE:-"Release"}
CMAKE_OPTS=${CMAKE_OPTS:-}
MACHINE_ID=${MACHINE_ID:-"wcoss2"}
COMPILER=${COMPILER:-"intel"}
BUILD_DIR=${BUILD_DIR:-"${DIR_ROOT}/sorc/build/wafs"}
INSTALL_PREFIX=${INSTALL_PREFIX:-"${DIR_ROOT}/sorc/install/wafs"}

#==============================================================================#

# Load modules
module reset
source "${DIR_ROOT}/versions/build.ver"
module use "${DIR_ROOT}/modulefiles"
module load "wafs_${MACHINE_ID}.${COMPILER}"
module list

# Collect BUILD Options
CMAKE_OPTS+=" -DCMAKE_BUILD_TYPE=${BUILD_TYPE}"

# Install destination for built executables, libraries, CMake Package config
CMAKE_OPTS+=" -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}"

# Re-use or create a new BUILD_DIR (Default: create new BUILD_DIR)
[[ ${BUILD_CLEAN:-"YES"} =~ [yYtT] ]] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}"

# Configure, build, install
set -x
cmake ${CMAKE_OPTS} "${DIR_ROOT}/sorc"
make -j "${BUILD_JOBS:-8}" VERBOSE="${BUILD_VERBOSE:-}"
make install
set +x

# Check WAFS/exec folder exists
if [[ ! -d "${DIR_ROOT}/exec" ]]; then
  mkdir -p "${DIR_ROOT}/exec"
fi

# Copy wafs executables to WAFS/exec
for exe in wafs_blending_0p25.x wafs_cnvgrib2.x wafs_gcip.x wafs_makewafs.x; do
  rm -rf "${DIR_ROOT}/exec/${exe}"
  cp "${INSTALL_PREFIX}/bin/${exe}" "${DIR_ROOT}/exec/${exe}"
done

exit

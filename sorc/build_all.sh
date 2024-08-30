#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/.." && pwd -P)

# User Options
export BUILD_TYPE=${BUILD_TYPE:-"Release"}
export BUILD_VERBOSE=${BUILD_VERBOSE:-"NO"}

# Check WAFS/exec folder exists, if not create it
if [[ ! -d "${DIR_ROOT}/exec" ]]; then
  mkdir -p "${DIR_ROOT}/exec"
fi

# Begin to compile
cd "${DIR_ROOT}/sorc"

# Collect build logs
mkdir -p "${DIR_ROOT}/sorc/logs"

echo "building ... wafs"
rm -f "${DIR_ROOT}/sorc/logs/log.wafs"
./build_wafs.sh >&"${DIR_ROOT}/sorc/logs/log.wafs" 2>&1

echo "building ... upp"
rm -f "${DIR_ROOT}/sorc/logs/log.upp"
./build_upp.sh >&"${DIR_ROOT}/sorc/logs/log.upp" 2>&1

echo "building ... done!"

echo "listing executables ..."
ls -l "${DIR_ROOT}/exec"

exit

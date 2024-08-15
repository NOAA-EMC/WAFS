#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

# Check WAFS/exec folder exists
if [[ ! -d "${DIR_ROOT}/exec" ]]; then
  mkdir -p "${DIR_ROOT}/exec"
fi

# upp_v8.3.0:
cd "${DIR_ROOT}/sorc/upp.fd"

# copy UPP parm/ to the main vertical structure
cp -r parm "${DIR_ROOT}/parm/upp"

# copy GTG code to UPP
cp sorc/post_gtg.fd/*f90 sorc/ncep_post.fd/.
cp sorc/post_gtg.fd/gtg.config.gfs parm/gtg.config.gfs

# Build upp executable file
cd "${DIR_ROOT}/sorc/upp.fd/sorc"
./build_ncep_post.sh

# Copy upp to WAFS/exec
rm -rf "${DIR_ROOT}/exec/ncep_post"
cp "${DIR_ROOT}/sorc/upp.fd/exec/ncep_post" "${DIR_ROOT}/exec/ncep_post"

exit

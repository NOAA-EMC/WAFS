#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/.." && pwd -P)

# Check WAFS/exec folder exists
if [[ ! -d "${DIR_ROOT}/exec" ]]; then
  mkdir -p "${DIR_ROOT}/exec"
fi

# upp_v8.3.0:
cd "${DIR_ROOT}/sorc/wafs_upp.fd"

# copy WAFS specific UPP parm/ files to the main vertical structure
mkdir -p "${DIR_ROOT}/parm/upp"
upp_parm_files=(nam_micro_lookup.dat \
                postcntrl_gfs_wafs_anl.xml \
                postcntrl_gfs_wafs_ext.xml \
                postcntrl_gfs_wafs.xml \
                postxconfig-NT-GFS-WAFS-ANL.txt \
                postxconfig-NT-GFS-WAFS-EXT.txt \
                postxconfig-NT-GFS-WAFS.txt \
                gtg_imprintings.txt )
for upp_parm_file in "${upp_parm_files[@]}"; do
  rm -f "${DIR_ROOT}/parm/upp/${upp_parm_file}"
  cp "parm/${upp_parm_file}" "${DIR_ROOT}/parm/upp/${upp_parm_file}"
done
rm -f "${DIR_ROOT}/parm/upp/gtg.config.gfs"
cp "sorc/post_gtg.fd/gtg.config.gfs" "${DIR_ROOT}/parm/upp/gtg.config.gfs"

# copy GTG code to UPP
cp -f sorc/post_gtg.fd/*f90 sorc/ncep_post.fd/.

# Build upp executable file
cd "${DIR_ROOT}/sorc/wafs_upp.fd/sorc"
./build_ncep_post.sh

# Copy upp to WAFS/exec
rm -rf "${DIR_ROOT}/exec/wafs_upp.x"
cp "${DIR_ROOT}/sorc/wafs_upp.fd/exec/ncep_post" "${DIR_ROOT}/exec/wafs_upp.x"

exit

#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

cd "${DIR_ROOT}"

# Checkout upp and gtg code
git -c submodule."post_gtg.fd".update=checkout submodule update --init --recursive

# upp:
cd "${DIR_ROOT}/sorc/wafs_upp.fd"

# copy WAFS specific UPP parm/ files to the main vertical structure
mkdir -p "${DIR_ROOT}/parm/upp"
upp_parm_files=(postcntrl_gfs_wafs_anl.xml \
                postcntrl_gfs_wafs_ext.xml \
                postcntrl_gfs_wafs.xml \
                postxconfig-NT-gfs-wafs-anl.txt \
                postxconfig-NT-gfs-wafs-ext.txt \
                postxconfig-NT-gfs-wafs.txt)
for upp_parm_file in "${upp_parm_files[@]}"; do
  rm -f "${DIR_ROOT}/parm/upp/${upp_parm_file}"
  cp "parm/gfs/${upp_parm_file}" "${DIR_ROOT}/parm/upp/${upp_parm_file}"
done
gtg_parm_files=(gtg.config.gfs \
		gtg.input.gfs \
                imprintings.gtg_gfs.txt)
for gtg_parm_file in "${gtg_parm_files[@]}"; do
    rm -f "${DIR_ROOT}/parm/upp/${gtg_parm_file}"
    cp "sorc/ncep_post.fd/post_gtg.fd/${gtg_parm_file}" "${DIR_ROOT}/parm/upp/${gtg_parm_file}"
done

exit

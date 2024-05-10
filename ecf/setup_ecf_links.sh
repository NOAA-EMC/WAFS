#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

ECF_DIR="${DIR_ROOT}/ecf"

# Function that loops over forecast hours and
# creates link between the master and target
function link_master_to_fhr(){
  tmpl=$1  # Name of the master template
  fhrs=$2  # Array of forecast hours
  for fhr in ${fhrs[@]}; do
    fhrchar=$(printf %03d $fhr)
    master=${tmpl}_master.ecf
    target=${tmpl}_f${fhrchar}.ecf
    rm -f ${target}
    ln -sf ${master} ${target}
  done
}


# grib files
cd "${ECF_DIR}/scripts/grib"
echo "Linking grib ..."
fhrs=($(seq 0 6 120))
link_master_to_fhr "jwafs_grib" "${fhrs}"

#!/bin/bash

# The script sets up the ecflow suite definition file for the WAFS workflow
# Usage: ./setup_ecf.sh PDYcyc [EXPID]
#   PDYcyc: Test date in YYYYMMDDHH format
#   EXPID: Experiment ID to distinguish different test runs (default: test)
# Example: ./setup_ecf.sh 2021010100 test
#
# Setting up ecflow suite requires the package to be cloned in a directory matching 'wafs.vX.Y.Z'
# where X, Y, Z are optional letters (lowercase) or numbers or combination of both
# The script replaces @VARIABLE@ names in suite definition files with values
# and links ecflow scripts in the ecf/scripts directory
#
# The script is expected to be run after the package is cloned and executables are built

set -eu

PDYcyc=${1:?"Provide a test date (YYYYMMDDHH)"}
EXPID=${2:-"test"} # Experiment ID to distinguish different test runs

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/../.." && pwd -P)

model="wafs"
modelver=$(echo ${DIR_ROOT} | perl -pe "s:.*?/${model}\.(v[\d\.a-z]+).*:\1:")
packageroot=$(dirname ${DIR_ROOT})

# Check if the directory ends with "wafs.vX.Y.Z"
packagename=$(basename ${DIR_ROOT})
pattern="^wafs\.v([0-9\.a-z]+).$"
if [[ ! "${packagename}" =~ ${pattern} ]]; then
    echo "FATAL ERROR: The package '${packagename}' should be cloned in a directory matching 'wafs.vX.Y.Z'"
    echo "             X, Y, Z are optional letters (lowercase) or numbers or combination of both"
    exit 1
fi

# Replace @VARIABLE@ names in suite definition files with values
echo "Create ecflow suite definition file 'wafs${EXPID}.def' in ... ecf/def"
sed -e "s|@EXPID@|${EXPID}|g" \
    -e "s|@MACHINE_SITE@|${MACHINE_SITE:-development}|g" \
    -e "s|@USER@|${USER}|g" \
    -e "s|@MODELVER@|${modelver}|g" \
    -e "s|@PACKAGEROOT@|${packageroot}|g" \
    -e "s|@PDY@|${PDYcyc:0:8}|g" \
    -e "s|@CYC@|${PDYcyc:8:2}|g" \
    "${DIR_ROOT}/ecf/def/wafs.def.tmpl" >"${DIR_ROOT}/ecf/def/wafs${EXPID}.def"

# Link ecflow scripts
echo "Link ecflow scripts in ... ecf/scripts"
cd "${DIR_ROOT}/ecf" || exit 1
./setup_ecf_links.sh

echo "... done"

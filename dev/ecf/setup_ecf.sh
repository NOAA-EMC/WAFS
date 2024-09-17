#!/bin/bash

# The script sets up the ecflow suite definition file for the WAFS workflow
# Usage: ./setup_ecf.sh [-d PDYcyc] [-x EXPID]
#   PDYcyc: Test date in YYYYMMDDHH format.  If blank, the current date and NRT mode is used (default: blank)
#   EXPID: Experiment ID to distinguish different test runs (default: None)
# Example: 1. ./setup_ecf.sh -d 2020011012 -x x001  # Use the specified date and experiment ID
#          2. ./setup_ecf.sh -x x001  # Use the current date and NRT mode
#
# Setting up ecflow suite requires the package to be cloned in a directory matching 'wafs.vX.Y.Z'
# where X, Y, Z are numbers
# The script replaces @VARIABLE@ names in suite definition files with values
# and links ecflow scripts in the ecf/scripts directory
#
# The script is expected to be run after the package is cloned and executables are built

set -eu

# Function to print usage
_usage() {
    echo "Usage: ./setup_ecf.sh [-d PDYcyc] [-x EXPID]"
    echo "  PDYcyc: Test date in YYYYMMDDHH format. If blank, the current date and NRT mode is used (default: blank)"
    echo "  EXPID: Experiment ID to distinguish different test runs (default: None)"
    echo "Example: 1. ./setup_ecf.sh -d 2020011012 -x x001  # Use the specified date and experiment ID"
    echo "         2. ./setup_ecf.sh -x x001  # Use the current date and NRT mode"
}

# Set defaults for key-value arguments
PDYcyc=""
EXPID=""

# Parse key-value arguments using getopts
while getopts ":d:x:h" opt; do
    case ${opt} in
    d)
        PDYcyc=${OPTARG}
        ;;
    x)
        EXPID=${OPTARG}
        ;;
    h)
        _usage
        exit 0
        ;;
    \?)
        echo "Invalid option: -${OPTARG}" >&2
        _usage
        exit 1
        ;;
    :)
        echo "Option -${OPTARG} requires an argument." >&2
        _usage
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

# Get the root of the cloned WAFS directory
declare -r DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/../.." && pwd -P)

model="wafs"
modelver=$(echo ${DIR_ROOT} | perl -pe "s:.*?/${model}\.(v[\d\.a-z]+).*:\1:")
packageroot=$(dirname ${DIR_ROOT})

# Check if the directory ends with "wafs.vX.Y.Z"
packagename=$(basename ${DIR_ROOT})
pattern="^wafs\.v([0-9\.a-z]+).$"
if [[ ! "${packagename}" =~ ${pattern} ]]; then
    echo "FATAL ERROR: The package '${packagename}' should be cloned in a directory matching 'wafs.vX.Y.Z'"
    echo "             X, Y, Z are numbers"
    exit 1
fi

# Check if PDYcyc is provided and in the right format to set template used to either wafs.def.tmpl or wafs_nrt.def.tmpl
if [[ -n "${PDYcyc}" ]]; then
    template="wafs.def.tmpl"
else
    PDYcyc=$(date --utc "+%Y%m%d%H")
    template="wafs_nrt.def.tmpl"
fi

# Echo out the settings for the user
echo "Settings:"
echo "  Model: ${model}.${modelver}"
echo "  Package Root: ${packageroot}"
if [[ -n "${EXPID}" ]]; then
    echo "  Experiment ID: ${EXPID}"
fi
echo "  Test date: ${PDYcyc}"
echo "  ecflow suite def template: ${template}"

# Replace @VARIABLE@ names in suite definition files with values
echo "Create ecflow suite definition file 'wafs${EXPID}.def' in ... ecf/def"
sed -e "s|@EXPID@|${EXPID}|g" \
    -e "s|@MACHINE_SITE@|${MACHINE_SITE:-development}|g" \
    -e "s|@USER@|${USER}|g" \
    -e "s|@MODELVER@|${modelver}|g" \
    -e "s|@PACKAGEROOT@|${packageroot}|g" \
    -e "s|@PDY@|${PDYcyc:0:8}|g" \
    -e "s|@CYC@|${PDYcyc:8:2}|g" \
    "${DIR_ROOT}/ecf/def/${template}" >"${DIR_ROOT}/ecf/def/wafs${EXPID}.def"

# Link ecflow scripts
echo "Link ecflow scripts in ... ecf/scripts"
cd "${DIR_ROOT}/ecf" || exit 1
./setup_ecf_links.sh

echo "... done"

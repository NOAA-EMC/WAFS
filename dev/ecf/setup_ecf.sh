#!/bin/bash

set -eu


# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/../.." && pwd -P)

ECF_DIR="${DIR_ROOT}/ecf"

model="wafs"
modelver=$(echo ${DIR_ROOT} | perl -pe "s:.*?/${model}\.(v[\d\.a-z]+).*:\1:")
packageroot=$(dirname ${DIR_ROOT})

# Replace @VARIABLE@ names in suite definition files with values
echo "Create ecflow suite definition file in ... ecf/def/wafs.def"
sed -e "s|@MACHINE_SITE@|${MACHINE_SITE:-development}|g" \
    -e "s|@USER@|${USER}|g" \
    -e "s|@MODELVER@|${modelver}|g" \
    -e "s|@PACKAGEROOT@|${packageroot}|g" \
    "${ECF_DIR}/def/wafs.def.tmpl" > "${ECF_DIR}/def/wafs.def"

# Link ecflow scripts
echo "Link ecflow scripts in ... ecf/scripts"
cd "${ECF_DIR}" || exit 1
./setup_ecf_links.sh

echo "... done"

#!/bin/bash

# Instructions: https://github.com/NOAA-EMC/WAFS/tree/release/wafs.v7/dev/ecf
#
# Two requirements to run this script
# 1. ecflow_server has been started
# 2. ecflow_server is started on either cdecflow01 or ddecflow01
#
# What the script will do:
# 1. Follow the instructions from dev/ecf/setup_ecf.sh and creates a suite definition file for real time parallel run
# 2. Load the suite def file to the ecflow_server which was started already
# 3. Begin parallel run of the suite in real time

set -eu

# Get the root of the script
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/../.." && pwd -P)
cd $DIR_ROOT/dev/ecf
# create a suite def file in real time
./setup_ecf.sh -x x001

suitename="wafsx001"

# set ECF_HOST according to which WCOSS2 machine
if [[ $(hostname) =~ ^[d][login|dxfer] ]]  ; then
    export ECF_HOST="ddecflow01"
elif [[ $(hostname) =~ ^[c][login|dxfer] ]]  ; then
    export ECF_HOST="cdecflow01"
fi
echo $ECF_HOST
module load ecflow

# Make sure ecflow_server is not halted
ecflow_client --restart

cd $DIR_ROOT/ecf/def

# echo "yes" | ecflow_client --delete=/$suitename
# ecflow_client --load $PWD/$suitename.def

# Replace: it can either load a new suite def or
# replace with a new suite def UNLESS a job is active for the current suite
ecflow_client --replace=/$suitename $PWD/$suitename.def

ecflow_client --begin $suitename

#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

# Checkout upp and gtg code
git submodule update --init --recursive 

############ upp_v8.3.0: copy GTG code to UPP  ############
cd "${DIR_ROOT}/sorc/upp.fd"
cp sorc/post_gtg.fd/*f90 sorc/ncep_post.fd/.
cp sorc/post_gtg.fd/gtg.config.gfs parm/gtg.config.gfs

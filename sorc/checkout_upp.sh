#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

# Checkout upp code
cd "${DIR_ROOT}/sorc"
git submodule update --init --recursive 

# Checkout upp/sorc/post_gtg code
cd "${DIR_ROOT}/sorc/upp.fd"
git -c submodule."post_gtg.fd".update=checkout submodule update --init --recursive

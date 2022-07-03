#!/bin/bash
set -ex

# detect machine
mac=$(hostname | cut -c1-1)
mac2=$(hostname | cut -c1-2)
if [ $mac = v -o $mac = m  ] ; then # For Dell
  machine=dell
  set +x
  module purge
  . $MODULESHOME/init/bash
  set -x
elif [ $mac2 = hf ] ; then          # For Hera
  machine=hera
  set +x
  module purge
  . /etc/profile
  . /etc/profile.d/modules.sh
  set -x
elif [ $mac = O ] ; then            # For Orion
  machine=orion
  set +x
  module purge
  . /etc/profile
  set -x
else
  machine=NULL
fi

if [ $machine = "dell" -o $machine = "hera" -o $machine = "orion" ]; then
  moduledir=`dirname $(readlink -f ../modulefiles/wafs)`
  set +x
#  module use ${moduledir}
#  module load wafs/wafs_v7.0.0-${machine}
  module use ${moduledir}/wafs
  module load wafs_v7.0.0-${machine}
  module list
  set -x
  INSTALL_PREFIX=${INSTALL_PREFIX:-"../../"}
  CMAKE_OPTS+=" -DCMAKE_INSTALL_BINDIR=exec"
fi

[[ -d build  ]] && rm -rf build
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX:-../} ${CMAKE_OPTS:-} ..
make -j ${BUILD_JOBS:-4} VERBOSE=${BUILD_VERBOSE:-}
make install

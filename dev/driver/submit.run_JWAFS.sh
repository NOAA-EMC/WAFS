#!/bin/bash

set -eu

# Get the root of the cloned WAFS directory
readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}")")/../.." && pwd -P)

job=${1?"Must specify a job to submit"}
PDYcyc=${2:-"2024110112"}
regression=${3:-"no"}

tmpdir=/lfs/h2/emc/ptmp/${USER}/working_wafs.${job}_${PDYcyc}
mkdir -p $tmpdir
cd $tmpdir

jobcard=run_JWAFS_${job^^}
cp "${DIR_ROOT}/dev/driver/${jobcard}" .


if [ $regression = 'yes' ] ; then
    # For regression tests: 
    export COMPATHgfs=/lfs/h2/emc/ptmp/yali.mao/regression/prod/com/gfs
    rm -rf $COMPATHgfs
    mkdir -p $COMPATHgfs/v17.0/gfs.${PDYcyc:0:8}/${PDYcyc:8:2}/model/atmos/history/
    ln -sf /lfs/h2/emc/vpppg/noscrub/wen.meng/test_suite/data_in/gfs/gfs.t00z.atmf006.nc $COMPATHgfs/v17.0/gfs.${PDYcyc:0:8}/${PDYcyc:8:2}/model/atmos/history/gfs.t00z.atm.f006.nc
    ln -sf /lfs/h2/emc/vpppg/noscrub/wen.meng/test_suite/data_in/gfs/gfs.t00z.sfcf006.nc $COMPATHgfs/v17.0/gfs.${PDYcyc:0:8}/${PDYcyc:8:2}/model/atmos/history/gfs.t00z.sfc.f006.nc
else
    # For GFSv17 tests
    export COMPATHgfs=/lfs/h2/emc/ptmp/yali.mao/gfs.realtime/prod/com/gfs
    rm -rf $COMPATHgfs
    mkdir -p $COMPATHgfs
    ln -sf /lfs/h2/emc/gfstemp/emc.global/comroot/retrov17_01_realtime $COMPATHgfs/v17.0
fi

if [ $job = 'upp' ]; then
  FHOURS="anl 000 006 007 008 009 010 011 012 013 014 015 016 017 018 019 020 021 022 023 024 \
  027 030 033 036 039 042 045 048 054 060 066 072 078 084 090 096 102 108 114 120"
elif [ $job = 'gcip' ]; then
  FHOURS="000 003"
elif [ $job = 'grib2_0p25' ]; then
  export FHOUT_GFS=${FHOUT_GFS:-1}
  if [ $FHOUT_GFS -eq 3 ]; then #27
    export FHOURS=${FHOURS:-"6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 54 60 66 72 78 84 90 96 102 108 114 120"}
  else #39
    export FHOURS=${FHOURS:-"6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 27 30 33 36 39 42 45 48 54 60 66 72 78 84 90 96 102 108 114 120"}
  fi
elif [ $job = 'grib2_1p25' ]; then
  export FHOURS=${FHOURS:-"00 06 09 12 15 18 21 24 27 30 33 36 42 48 54 60 66 72"}
elif [ $job = 'grib' ]; then
  export FHOURS=${FHOURS:-"06 12 18 24 30 36 42 48 54 60 66 72"}
elif [ $job = 'grib2_0p25_blending' ]; then
  sed -e "s|log.wafs_$job|log.wafs_$job|g" \
  -e "s|HOMEwafs=.*|HOMEwafs=$DIR_ROOT|g" \
  -e "s|PDY=.*|PDY=${PDYcyc:0:8}|g" \
  -e "s|cyc=.*|cyc=${PDYcyc:8:2}|g" \
  -e "s|working_wafs|working_wafs.${job}_${PDYcyc}|g" \
  -i $jobcard
  qsub $jobcard
  exit
fi

for fhr in $FHOURS; do
  if [ $job = 'grib' ]; then
    fhr="$(printf "%02d" $(( 10#$fhr )) )"
  else
    if [ ! $fhr = "anl" ] ; then
      fhr="$(printf "%03d" $(( 10#$fhr )) )"
    fi
  fi

  sed -e "s|log.wafs_$job|log.wafs_$job.$fhr|g" \
  -e "s|HOMEwafs=.*|HOMEwafs=$DIR_ROOT|g" \
  -e "s|COMPATHgfs=.*|COMPATHgfs=$COMPATHgfs|g" \
  -e "s|PDY=.*|PDY=${PDYcyc:0:8}|g" \
  -e "s|cyc=.*|cyc=${PDYcyc:8:2}|g" \
  -e "s|fhr=.*|fhr=$fhr|g" \
  -e "s|working_wafs|working_wafs.${job}_${PDYcyc}|g" \
  $jobcard >$jobcard.$fhr

  qsub $jobcard.$fhr
done


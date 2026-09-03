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

members="one"
if [ $job = 'upp' ]; then
  FHOURS="anl 000 $(seq -w 6 1 024) $(seq -w 27 3 048) $(seq -w 54 6 120)"
elif [ $job = 'gcip' ]; then
  FHOURS="000 003"
elif [ $job = 'gefs_upp' ]; then
  FHOURS="$(seq -w 6 3 048)"
  members=$(seq -w 1 30 | sed 's/^/gep/' | tr '\n' ' ')
  members="gec00 ${members}"
elif [ $job = 'grib2_0p25' ]; then
  export FHOUT_GFS=${FHOUT_GFS:-1}
  if [ $FHOUT_GFS -eq 3 ]; then #27
      export FHOURS="$(seq 6 3 48) $(seq 54 6 120)"
  else #39
      export FHOURS="$(seq 6 1 24) $(seq 27 3 48) $(seq 54 6 120)"
  fi
elif [ $job = 'grib2_1p25' ]; then
    FHOURS="00 $(seq -w 6 3 36) $(seq 42 6 72)"
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

  for RUNMEM in $members ; do
      if [ $RUNMEM = "one" ] ; then
	  appendix=""
      else
	  appendix=".$RUNMEM"
      fi
      sed -e "s|log.wafs_$job|log.wafs_$job.$fhr$appendix|g" \
	  -e "s|HOMEwafs=.*|HOMEwafs=$DIR_ROOT|g" \
	  -e "s|COMPATHgfs=.*|COMPATHgfs=$COMPATHgfs|g" \
	  -e "s|PDY=.*|PDY=${PDYcyc:0:8}|g" \
	  -e "s|cyc=.*|cyc=${PDYcyc:8:2}|g" \
	  -e "s|fhr=.*|fhr=$fhr|g" \
	  -e "s|working_wafs|working_wafs.${job}_${PDYcyc}|g" \
	  -e "s|RUNMEM=.*|RUNMEM=$RUNMEM|g" \
	  $jobcard >$jobcard.$fhr$appendix
      qsub $jobcard.$fhr$appendix
  done
      
done


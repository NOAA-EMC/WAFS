#!/bin/bash

################################################################################
#  UTILITY SCRIPT NAME :  exwafs_grib2_0p25_blending.sh
#         DATE WRITTEN :  10/02/2024
#
#  Abstract:  This script runs blending script, ush/wafs_grib2_0p25_blending.sh,
#             using MPMD to parallel run for each forcast hour.
#             It handles the situation of UK missing data and sends out email per cycle
#
#  History:  10/02/2024 - WAFS separation
#              - MPMD parallel run for each forecast hour, changed from sequential run.
#              - Fix bugzilla 1593: Improve email notification for missing UK WAFS data.
#              - Fix bugzilla 1226: Eliminate the duplicated dbn_alert for unblended wafs data
################################################################################

set -x

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

fhours=${fhours:-"006 007 008 009 010 011 012 013 014 015 016 017 018 019 020 021 022 023 024 027 030 033 036 039 042 045 048"}
np=`echo $fhours | wc -w`
MPIRUN="mpiexec -np $np -cpu-bind verbose,core cfp"

rm -f wafsgrib2_0p25.cmdfile
ic=0
for fhr in $fhours ; do
  if [[ $(echo $MPIRUN | cut -d " " -f1) = 'srun' ]] ; then
    echo "$ic ${USHwafs}/wafs_grib2_0p25_blending.sh $fhr > $DATA/${fhr}.log 2>&1" >> wafsgrib2_0p25.cmdfile
  else
    echo "${USHwafs}/wafs_grib2_0p25_blending.sh $fhr > $DATA/${fhr}.log 2>&1">> wafsgrib2_0p25.cmdfile
    export MP_PGMMODEL=mpmd
  fi
  ic=$(expr $ic + 1)
done
$MPIRUN wafsgrib2_0p25.cmdfile

missing_uk_files="$(find $DATA -name 'missing_uk_files*')"

if [[ ! -z "$missing_uk_files" ]] ; then

    echo "WARNING: Missing UK data for WAFS GRIB2 0P25 blending. Send alert message to AWC ......"
    make_NTC_file.pl NOXX10 KKCI "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/wifs_0p25_admin_msg"
    make_NTC_file.pl NOXX10 KWBC "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/iscs_0p25_admin_msg"
    if [[ "${SENDDBN_NTC}" == "YES" ]]; then
        "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/wifs_0p25_admin_msg"
        "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/iscs_0p25_admin_msg"
    fi

    subject="WARNING! Missing UK data for WAFS GRIB2 0P25 blending, ${PDY} t${cyc}z ${job}"
    echo "*************************************************************" >mailmsg
    echo "*** WARNING! Missing UK data for WAFS GRIB2 0P25 blending ***" >>mailmsg
    echo "*************************************************************" >>mailmsg
    echo >>mailmsg
    echo "Send alert message to AWC ...... " >>mailmsg
    echo >>mailmsg
    echo "All missing files:" >>mailmsg
    echo "------------------" >>mailmsg
    for file in $missing_uk_files ; do
	cat $file >>mailmsg
    done

    cat mailmsg >"${COMOUT}/${RUN}.t${cyc}z.wafs_blend_0p25_usonly.emailbody"
    cat "${COMOUT}/${RUN}.t${cyc}z.f${fhr}.wafs_blend_0p25_usonly.emailbody" | mail.py -s "${subject}" "${MAILTO}" -v
fi

for fhr in $fhours ; do
    echo "=================== log file of fhr=$fhr ==================="
    cat $DATA/${fhr}.log
done

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

fhours=($(seq -s ' ' -f "%03g" 6 1 24; seq -s ' ' -f "%03g" 27 3 48))

rm -f wafsgrib2_0p25.cmdfile
for fhr in ${fhours[@]}; do
    echo "${USHwafs}/wafs_grib2_0p25_blending.sh $fhr > $DATA/${fhr}.log 2>&1">> wafsgrib2_0p25_blending.cmdfile
done
export MP_PGMMODEL=mpmd
MPIRUN="mpiexec -np ${#fhours[@]} -cpu-bind verbose,core cfp"
$MPIRUN wafsgrib2_0p25_blending.cmdfile

export err=$?
if (( err != 0 )); then
    echo "FATAL ERROR: An error occured processing blending"
fi

for fhr in ${fhours[@]}; do
    echo "=================== log file of fhr=$fhr ==================="
    cat "${DATA}/${fhr}.log"
done
echo "===================== end of log files ====================="

missing_uk_files="$(find $DATA -name 'missing_uk_files*')"
missing_us_files="$(find $DATA -name 'missing_us_files*')"
no_blending_files="$(find $DATA -name 'no_blending_files*')"

if [[ ! -z "$missing_uk_files" ]] || [[ ! -z "$missing_us_files" ]] || [[ ! -z "$no_blending_files" ]] ; then
    echo "WARNING: No WAFS GRIB2 0P25 blending. Send alert message to AWC ......"
    make_NTC_file.pl NOXX10 KKCI "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/wifs_0p25_admin_msg"
    make_NTC_file.pl NOXX10 KWBC "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/iscs_0p25_admin_msg"
    if [[ "${SENDDBN_NTC}" == "YES" ]]; then
        "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/wifs_0p25_admin_msg"
        "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/iscs_0p25_admin_msg"
    fi
fi

if [[ ! -z "$missing_uk_files" ]] ; then
    subject="WARNING! Missing UK data for WAFS GRIB2 0P25 blending, ${PDY} t${cyc}z ${job}"
    echo "*************************************************************" >mailmsg
    echo "*** WARNING! Missing UK data for WAFS GRIB2 0P25 blending ***" >>mailmsg
    echo "*************************************************************" >>mailmsg
    echo >>mailmsg
    echo "Send alert message to AWC ...... " >>mailmsg
    echo >>mailmsg
    for file in $missing_uk_files ; do
	cat $file >>mailmsg
    done

    cat mailmsg >"${COMOUT}/${RUN}.t${cyc}z.wafs_blend_0p25_ukmissing.emailbody"
    cat "${COMOUT}/${RUN}.t${cyc}z.wafs_blend_0p25_ukmissing.emailbody" | mail.py -s "${subject}" "${MAILTO}" -v
fi


if [[ ! -z "$missing_us_files" ]] ; then
    subject="WARNING! Missing US data for WAFS GRIB2 0P25 blending, ${PDY} t${cyc}z ${job}"
    echo "*************************************************************" >mailmsg
    echo "*** WARNING! Missing US data for WAFS GRIB2 0P25 blending ***" >>mailmsg
    echo "*************************************************************" >>mailmsg
    echo >>mailmsg
    echo "Send alert message to AWC ...... " >>mailmsg
    echo >>mailmsg
    for file in $missing_us_files ; do
        cat $file >>mailmsg
    done

    cat mailmsg >"${COMOUT}/${RUN}.t${cyc}z.wafs_blend_0p25_usmissing.emailbody"
    cat "${COMOUT}/${RUN}.t${cyc}z.wafs_blend_0p25_usmissing.emailbody" | mail.py -s "${subject}" "${MAILTO}" -v
fi

if [[ ! -z "$no_blending_files" ]] ; then
    subject="WARNING! Not blended for WAFS GRIB2 0P25 blending, ${PDY} t${cyc}z ${job}"
    echo "*************************************************************" >mailmsg
    echo "*** WARNING! Not blended for WAFS GRIB2 0P25 blending     ***" >>mailmsg
    echo "*************************************************************" >>mailmsg
    echo >>mailmsg
    echo "Send alert message to AWC ...... " >>mailmsg
    echo >>mailmsg
    for file in $no_blending_files ; do
        cat $file >>mailmsg
    done

    cat mailmsg >"${COMOUT}/${RUN}.t${cyc}z.wafs_blend_0p25_noblending.emailbody"
    cat "${COMOUT}/${RUN}.t${cyc}z.wafs_blend_0p25_noblending.emailbody" | mail.py -s "${subject}" "${MAILTO}" -v
fi

export err=$? ; err_chk

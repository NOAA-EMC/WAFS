#!/bin/bash

################################################################################
#  UTILITY SCRIPT NAME :  exwafs_grib2_0p25_blending.sh
#         DATE WRITTEN :  04/02/2020
#
#  Abstract:  This script looks for US and UK WAFS Grib2 products at 1/4 deg,
#             waits unblended UK data for specified period of time, and blends
#             whenever UK data becomes available. After the waiting time window
#             expires, the script sends out US data only if UK data doesn't arrive
#
#  History:  04/02/2020 - First implementation of this new script
#            10/xx/2021 - Remove jlogfile
#            05/25/2022 - Add ICAO new milestone Nov 2023
#            09/08/2024 - WAFS separation
#              - Filename changes according to EE2 standard except for files sent to UK
#              - dbn_alert subtype is changed from gfs to WAFS
#              - Fix bugzilla 1213: Filename should use fHHH instead of FHH.
#              - Parallel run for each forecast hour, changed from sequential run.
#              - Fix bugzilla 1593: Improve email notification for missing UK WAFS data.
#              - Extend waiting time window from 15 to 25 minutes
################################################################################

set -x

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

SEND_US_WAFS="NO"
SEND_UK_WAFS="NO"
##########################
# look for US WAFS data
##########################
if [[ ! -s "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" ]]; then
    echo "Not found US WAFS GRIB2 file '${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2', continue ..."
    SEND_UK_WAFS="YES"
fi

##########################
# look for UK WAFS data.
##########################
###############################################
# Specify Timeout Behavior for WAFS blending
###############################################
# SLEEP_TIME - Amount of time (secs) to wait for a input file before exiting
# SLEEP_INT  - Amount of time (secs) to wait between checking for input files
SLEEP_TIME=${SLEEP_TIME:-1500}
SLEEP_INT=${SLEEP_INT:-10}
SLEEP_LOOP_MAX=$((SLEEP_TIME / SLEEP_INT))

for ((ic = 1; ic <= SLEEP_LOOP_MAX; ic++)); do
    # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
    ukfiles=$(find "${COMINuk}" -name "egrr_wafshzds_unblended_*_0p25_${PDY:0:4}-${PDY:4:2}-${PDY:6:2}T${cyc}:00Z_t${fhr}.grib2" | wc -l)
    if ((ukfiles >= 3)); then
        echo "Found all 3 UK WAFS GRIB2 files, continue ..."
        break
    fi

    if ((ic == SLEEP_LOOP_MAX)); then
        products="cb ice turb"
        for prod in ${products}; do
            ukfile="egrr_wafshzds_unblended_${prod}_0p25_${PDY:0:4}-${PDY:4:2}-${PDY:6:2}T${cyc}:00Z_t${fhr}.grib2"
            if [[ ! -f "${COMINuk}/${ukfile}" ]]; then
                echo "WARNING: UK WAFS GRIB2 file '${ukfile}' not found after waiting over ${SLEEP_TIME} seconds"
                echo "${ukfile}" >>missing_uk_files
            fi
        done
        echo "WARNING: UK WAFS GRIB2 unblended data is not completely available, no blending"
        SEND_US_WAFS="YES"
        break
    else
        sleep "${SLEEP_INT}"
    fi
done

##########################
# If both UK and US data are missing.
##########################
if [[ "${SEND_US_WAFS}" == "YES" ]] && [[ "${SEND_UK_WAFS}" == "YES" ]]; then
    SEND_US_WAFS=NO
    SEND_UK_WAFS=NO
    export err=1
    err_exit "FATAL ERROR: Both US and UK data are missing, no blended products for '${PDY}${cyc}f${fhr}'"
fi

##########################
# Blending or unblended
##########################

if [[ "${SEND_US_WAFS}" == "YES" ]]; then
    echo "turning back on dbn alert for unblended US WAFS product"
elif [[ "${SEND_UK_WAFS}" == "YES" ]]; then
    echo "turning back on dbn alert for unblended UK WAFS product"
    # retrieve UK products
    # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
    cat "${COMINuk}/egrr_wafshzds_unblended_"*"_0p25_${PDY:0:4}-${PDY:4:2}-${PDY:6:2}T${cyc}:00Z_t${fhr}.grib2" >"EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2"
else
    # retrieve UK products
    # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
    cat "${COMINuk}/egrr_wafshzds_unblended_"*"_0p25_${PDY:0:4}-${PDY:4:2}-${PDY:6:2}T${cyc}:00Z_t${fhr}.grib2" >"EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2"

    # pick up US data
    cpreq "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" .

    # run blending code
    export pgm="wafs_blending_0p25.x"

    . prep_step

    ${EXECwafs}/${pgm} "WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" \
        "EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2" \
        "0p25_blended_${PDY}${cyc}f${fhr}.grib2 >f${fhr}.out"
    err=$?
    if ((err != 0)); then
        echo "WARNING: WAFS blending 0p25 program failed at '${PDY}${cyc}f${fhr}'. Turning back on dbn alert for unblended US WAFS product"
        SEND_US_WAFS="YES"
    fi
fi

##########################
# Data dissemination
##########################

# Set up mailing list
if [[ "${envir}" != "prod" ]]; then
    maillist="nco.spa@noaa.gov"
fi
maillist=${maillist:-"nco.spa@noaa.gov,ncep.sos@noaa.gov"}

if [[ "${SEND_US_WAFS}" == "YES" ]]; then

    #  checking any US WAFS product was sent due to No UK WAFS GRIB2 file or WAFS blending program
    #  (Alert once for each forecast hour)
    if [[ ! -f ${COMOUTwmo}/wifs_0p25_admin_msg ]]; then
        echo "WARNING: Missing UK data for WAFS GRIB2 0P25 blending. Send alert message to AWC ......"
        make_NTC_file.pl NOXX10 KKCI "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/wifs_0p25_admin_msg"
        make_NTC_file.pl NOXX10 KWBC "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/iscs_0p25_admin_msg"
        if [[ "${SENDDBN_NTC}" == "YES" ]]; then
            "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/wifs_0p25_admin_msg"
            "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/iscs_0p25_admin_msg"
        fi

        subject="WARNING! Missing UK data for WAFS GRIB2 0P25 blending, ${PDY} t${cyc}z f${fhr} ${job}"
        echo "*************************************************************" >mailmsg
        echo "*** WARNING! Missing UK data for WAFS GRIB2 0P25 blending ***" >>mailmsg
        echo "*************************************************************" >>mailmsg
        echo "Missing data at ${COMINuk}:" >>mailmsg
        cat missing_uk_files >>mailmsg
        echo >>mailmsg
        echo "Send alert message to AWC ...... " >>mailmsg
        echo >>mailmsg
        cat mailmsg >"${COMOUT}/${RUN}.t${cyc}z.f${fhr}.wafs_blend_0p25_usonly.emailbody"
        cat "${COMOUT}/${RUN}.t${cyc}z.f${fhr}.wafs_blend_0p25_usonly.emailbody" | mail.py -s "${subject}" "${maillist}" -v
    fi

    # Distribute US WAFS unblend Data to NCEP FTP Server (WOC) and TOC
    echo "altering the unblended US WAFS products:"
    echo " - ${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
    echo " - ${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx"

    if [[ "${SENDDBN}" == "YES" ]]; then
        "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_UBL_GB2 "${job}" "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
        "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_UBL_GB2_WIDX "${job}" "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx"
    fi

elif [[ "${SEND_UK_WAFS}" == "YES" ]]; then

    #  checking any UK WAFS product was sent due to No US WAFS GRIB2 file
    #  (Alert once for each forecast hour)
    if [[ ! -f ${COMOUTwmo}/wifs_0p25_admin_msg ]]; then
        echo "WARNING: Missing US data for WAFS GRIB2 0P25 blending. Send alert message to AWC ......"
        make_NTC_file.pl NOXX10 KKCI "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/wifs_0p25_admin_msg"
        make_NTC_file.pl NOXX10 KWBC "${PDY}${cyc}" NONE "${FIXwafs}/wafs/wafs_blending_0p25_admin_msg" "${COMOUTwmo}/iscs_0p25_admin_msg"
        if [[ "${SENDDBN_NTC}" == "YES" ]]; then
            "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/wifs_0p25_admin_msg"
            "${DBNROOT}/bin/dbn_alert" NTC_LOW WAFS "${job}" "${COMOUTwmo}/iscs_0p25_admin_msg"
        fi

        export subject="WARNING! Missing US data for WAFS GRIB2 0P25 blending, ${PDY} t${cyc}z ${fhr} ${job}"
        echo "*************************************************************" >mailmsg
        echo "*** WARNING! Missing US data for WAFS GRIB2 0P25 blending ***" >>mailmsg
        echo "*************************************************************" >>mailmsg
        echo "Missing data at ${COMINus}:" >>mailmsg
        echo "WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" >>mailmsg
        echo >>mailmsg
        echo "Send alert message to AWC ...... " >>mailmsg
        echo >>mailmsg
        cat mailmsg >"${COMOUT}/${RUN}.t${cyc}z.f${fhr}.wafs_blend_0p25_ukonly.emailbody"
        cat "${COMOUT}/${RUN}.t${cyc}z.f${fhr}.wafs_blend_0p25_ukonly.emailbody" | mail.py -s "${subject}" "${maillist}" -v

    fi
    #   Distribute UK WAFS unblend Data to NCEP FTP Server (WOC) and TOC
    echo "altering the unblended UK WAFS products - EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2"

    if [[ "${SENDDBN}" == "YES" ]]; then
        "${DBNROOT}/bin/dbn_alert" MODEL WAFS_UKMET_0P25_UBL_GB2 "${job}" "EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2"
    fi

else
    # Distribute US WAFS unblend Data to NCEP FTP Server (WOC) and TOC
    if [[ "${SENDCOM}" == "YES" ]]; then
        cpfs "0p25_blended_${PDY}${cyc}f${fhr}.grib2" "${COMOUT}/WAFS_0p25_blended_${PDY}${cyc}f${fhr}.grib2"
    fi

    if [[ "${SENDDBN_NTC}" == "YES" ]]; then
        #   Distribute Data to NCEP FTP Server (WOC) and TOC
        echo "No WMO header yet"
    fi

    if [[ "${SENDDBN}" == "YES" ]]; then
        "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_BL_GB2 "${job}" "${COMOUT}/WAFS_0p25_blended_${PDY}${cyc}f${fhr}.grib2"
    fi
fi

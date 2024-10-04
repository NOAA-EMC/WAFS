#!/bin/bash

################################################################################
#  UTILITY SCRIPT NAME :  wafs_grib2_0p25_blending.sh
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

fhr=$1

mkdir -p "${DATA}/${fhr}"
cd "${DATA}/${fhr}" || err=1

###############################################
# Specify Timeout Behavior for WAFS blending
###############################################
# SLEEP_TIME - Amount of time (secs) to wait for a input file before exiting
# SLEEP_INT  - Amount of time (secs) to wait between checking for input files
SLEEP_TIME=${SLEEP_TIME:-1500}
SLEEP_INT=${SLEEP_INT:-10}
SLEEP_LOOP_MAX=$((SLEEP_TIME / SLEEP_INT))

##########################
# look for UK WAFS data.
##########################
MISSING_UK_WAFS="NO"

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
                echo "Missing ${COMINuk}/${ukfile}" >> ../missing_uk_files.$fhr
            fi
        done
        echo "WARNING: UK WAFS GRIB2 unblended data is not completely available, no blending"
        MISSING_UK_WAFS="YES"
        break
    else
        sleep "${SLEEP_INT}"
    fi
done

##########################
# look for US WAFS data.
##########################
MISSING_US_WAFS="NO"

if [[ ! -f "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx" ]]; then
    # Blending ecflow run is triggered by the finishing of the upstream JWAFS_GRIB2_0P25 f048
    #  - In real time ecflow, blending starts at T+4:30, unblended upstream products are all available.
    #    It doesn't need to sleep/wait
    #  - In non-real time ecflow, blending has no time tigger, unblended f048 is not guaranteed to be the last finished one.
    #    It needs to sleep/wait. All upstream jobs can be finished within 60 seconds when f048 is finished.
    #
    # Standalone blending doesn't need to sleep/wait since unblended upstream grib2_0p25 runs standalone first.
    sleep 60
    if [[ ! -f "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx" ]]; then
	echo "WARNING: missing US unblended data - ${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
	echo "Missing ${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" > ../missing_us_files.$fhr
	MISSING_US_WAFS="YES"
    fi
fi

##########################
# Blending or unblended
##########################
if [[ "${MISSING_UK_WAFS}" == "YES" ]] && [[ "${MISSING_US_WAFS}" == "YES" ]]; then
    cat ../missing_uk_files.$fhr ../missing_us_files.$fhr > ../no_blending_files.$fhr
    rm ../missing_uk_files.$fhr ../missing_us_files.$fhr
elif [[ "${MISSING_UK_WAFS}" == "YES" ]]; then
    echo "turning back on dbn alert for unblended US WAFS product"
    # Avoid duplicate dbn_alert of unblended grib2 file which was done in the upstream grib2_0p25 job, fix bugzilla 1226
    # "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_UBL_GB2 "${job}" "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
    "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_UBL_GB2_WIDX "${job}" "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx"
else
    # retrieve UK products
    # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
    cat "${COMINuk}/egrr_wafshzds_unblended_"*"_0p25_${PDY:0:4}-${PDY:4:2}-${PDY:6:2}T${cyc}:00Z_t${fhr}.grib2" >"EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2"

    if [[ "${MISSING_US_WAFS}" == "YES" ]]; then
	if [ $SENDDBN = "YES" ] ; then
	    "$DBNROOT/bin/dbn_alert" MODEL WAFS_UKMET_0P25_UBL_GB2 "${job}" "EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2"
	fi
    else
	# pick up US data
	cpreq "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" .

	# run blending code
	export pgm="wafs_blending_0p25.x"

	. prep_step

	${EXECwafs}/${pgm} "WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" \
		   "EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2" \
		   "0p25_blended_${PDY}${cyc}f${fhr}.grib2 >f${fhr}.out"

	err=$?
	if (( err != 0 )); then
	    echo "turning back on dbn alert for unblended US WAFS product"
	    "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_UBL_GB2_WIDX "${job}" "${COMINus}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx"
	    echo "WAFS blending 0p25 program failed at " ${PDY}${cyc}F${fhr} > ../no_blending_files.$fhr
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
    fi
fi

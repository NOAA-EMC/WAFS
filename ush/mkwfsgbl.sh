#!/bin/bash

################################################################################
#  UTILITY SCRIPT NAME :  mkwfsgbl.sh
#               AUTHOR :  Mary Jacobs
#         DATE WRITTEN :  11/06/96
#
#  Abstract:  This utility script produces the GFS WAFS
#             bulletins.
#
#     Input:  2 arguments are passed to this script.
#             1st argument - Forecast Hour - format of 2I
#             2nd argument - In hours 12-30, the designator of
#                            a  or  b.
#
#     Logic:   If we are processing hours 12-30, we have the
#              added variable of the   a   or    b, and process
#              accordingly.  The other hours, the a or b  is dropped.
#
#   History: SEPT    1996 - First implementation of this utility script"
#            AUG     1999 - Modified for implementation on IBM SP"
#                         - Allows users to run interactively"
#            SEP     2007 - BAG - Put in fix on 20070925 to force the percision of U and V winds
#                           to default to 1 through the use of the grib_wafs.namelist file.
################################################################################

set -x

fhr=${1:-?"fhr is missing"}
sets_key=${2:-?"sets_key is missing"}

set +x
echo " ------------------------------------------"
echo " BEGIN MAKING gfs WAFS PRODUCTS"
echo " ------------------------------------------"

echo "Enter Make WAFS utility."
set -x

ifhr=$((10#$fhr))
fhr3=$(printf "%03i" "${ifhr}")
GFS_MASTER="${COMINgfs}/gfs.t${cyc}z.master.grb2f${fhr3}"

##############################
# Copy Input Field to $DATA
##############################

if [[ ! -f "pgrbf${fhr}" ]]; then

    cpreq "${GFS_MASTER}" "./gfs_masterf${fhr}.grib2"
    ${WGRIB2} "./gfs_masterf${fhr}.grib2" | grep -F -f "${FIXwafs}/wafs/grib_wafs.grb2to1.list" | ${WGRIB2} -i "./gfs_masterf${fhr}.grib2" -grib "masterf${fhr}"

    # Change data input from 1p00 files to master files
    export opt1=' -set_grib_type same -new_grid_winds earth '
    export opt21=' -new_grid_interpolation bilinear '
    export opt24=' -set_bitmap 1 -set_grib_max_bits 16 -if '
    export opt25=":(APCP|ACPCP):"
    export opt26=' -set_grib_max_bits 25 -fi -if '
    export opt27=":(APCP|ACPCP):"
    export opt28=' -new_grid_interpolation budget -fi '
    export grid1p0="latlon 0:360:1.0 90:181:-1.0"
    ${WGRIB2} "masterf${fhr}" ${opt1} ${opt21} ${opt24} ${opt25} ${opt26} ${opt27} ${opt28} \
        -new_grid ${grid1p0} "pgb2file_${fhr}1p00"

    # trim RH vaule larger than 100.
    ${WGRIB2} "pgb2file_${fhr}1p00" -not_if ':RH:' -grib "pgrb2f${fhr}.tmp" \
        -if ':RH:' -rpn "10:*:0.5:+:floor:1000:min:10:/" -set_grib_type same \
        -set_scaling -1 0 -grib_out "pgrb2f${fhr}.tmp"

    ${CNVGRIB} -g21 "pgrb2f${fhr}.tmp" "pgrbf${fhr}"
fi

${COPYGB} -g3 -i0 -N${FIXwafs}/wafs/grib_wafs.namelist -x "pgrbf${fhr}" tmp
mv tmp "pgrbf${fhr}"
${GRBINDEX} "pgrbf${fhr}" "pgrbif${fhr}"

##############################
# Process WAFS
##############################

if ((ifhr >= 12 && ifhr <= 30)); then
    sets=${sets_key}
    set +x
    echo "We are processing the primary and secondary sets of hours."
    echo "These sets are the   a   and   b   of hours 12-30."
    set -x
else
    # This is for hours 00/06 and 36-72.
    unset sets
fi

export pgm="wafs_makewafs.x"

. prep_step

export FORT11="pgrbf${fhr}"
export FORT31="pgrbif${fhr}"
export FORT51="xtrn.wfsgfs${fhr}${sets}"
export FORT53="com.wafs${fhr}${sets}"

${EXECwafs}/${pgm} <"${FIXwafs}/wafs/grib_wfsgfs${fhr}${sets}" >>"${pgmout}" 2>errfile
export err=$?
err_chk

if [[ ! -f "xtrn.wfsgfs${fhr}${sets}" ]]; then
    err_exit "FATAL ERROR: '${pgm}' failed to create 'xtrn.wfsgfs${fhr}${sets}'"
fi

# Send data to COM
jobsuffix="gfs_atmos_wafs_f${fhr}_$cyc"
if [[ "${SENDCOM}" == "YES" ]]; then
    cpfs "xtrn.wfsgfs${fhr}${sets}" "${COMOUTwmo}/xtrn.wfsgfs${cyc}${fhr}${sets}.${jobsuffix}"
fi

# Alert via DBN
if [[ "${SENDDBN_NTC}" == "YES" ]]; then
    "${DBNROOT}/bin/dbn_alert" GRIB_LOW gfs "${job}" "${COMOUTwmo}/xtrn.wfsgfs${cyc}${fhr}${sets}.${jobsuffix}"
else
    echo "xtrn.wfsgfs${cyc}${fhr}${sets}.${job} file not posted to db_net."
fi

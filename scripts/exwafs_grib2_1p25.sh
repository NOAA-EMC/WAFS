#!/bin/bash

######################################################################
#  UTILITY SCRIPT NAME :  exwafs_grib2.sh
#         DATE WRITTEN :  07/15/2009
#
#  Abstract:  This utility script produces the WAFS GRIB2. The output
#             GRIB files are posted on NCEP ftp server and the grib2 files
#             are pushed via dbnet to TOC to WAFS (ICSC).
#             This is a joint project of WAFC London and WAFC Washington.
#
#             We are processing WAFS grib2 for fhr from 06 - 36
#             with 3-hour time increment.
#
# History:  08/20/2014
#              - ingest master file in grib2 (or grib1 if grib2 fails)
#              - output of icng tcld cat cb are in grib2
#           02/21/2020
#              - Prepare unblended icing severity and GTG tubulence
#                for blending at 0.25 degree
#           02/22/2022
#              - Add grib2 data requested by FAA
#              - Stop generating grib1 data for WAFS
#####################################################################

set -x

GFS_MASTER="${COMINgfs}/gfs.t${cyc}z.master.grb2f${fhr}"
WAFS_MASTER="${COMIN}/${RUN}.t${cyc}z.master.f${fhr}.grib2"

ifhr="$((10#${fhr}))"
if ((ifhr > 0 && ifhr <= 36)); then
    wafs_timewindow="YES"
else
    wafs_timewindow="NO"
fi

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

#---------------------------
# 1) Grib2 data for FAA
#---------------------------
cpreq "${GFS_MASTER}" ./gfs_master.grib2
${WGRIB2} "./gfs_master.grib2" | grep -F -f "${FIXwafs}/grib2_gfs_awf_master.list" | ${WGRIB2} -i "./gfs_master.grib2" -grib "tmpfile_wafsf${fhr}"

# F006 master file has two records of 0-6 hour APCP and ACPCP each, keep only one
# FAA APCP ACPCP: included every 6 forecast hour (0, 48], every 12 forest hour [48, 72] (controlled by ${FIXwafs}/grib2_gfs_awf_master.list)
if ((ifhr == 6)); then
    ${WGRIB2} "tmpfile_wafsf${fhr}" -not "(APCP|ACPCP)" -grib tmp.grb2
    ${WGRIB2} "tmpfile_wafsf${fhr}" -match APCP -append -grib tmp.grb2 -quit
    ${WGRIB2} "tmpfile_wafsf${fhr}" -match ACPCP -append -grib tmp.grb2 -quit
    mv tmp.grb2 "tmpfile_wafsf${fhr}"
fi

# U V will have the same grid message number by using -ncep_uv.
# U V will have the different grid message number without -ncep_uv.
${WGRIB2} "tmpfile_wafsf${fhr}" \
    -set master_table 6 \
    -new_grid_winds earth -set_grib_type jpeg \
    -new_grid_interpolation bilinear -if ":(UGRD|VGRD):max wind" -new_grid_interpolation neighbor -fi \
    -new_grid latlon 0:288:1.25 90:145:-1.25 "${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2"
${WGRIB2} -s "${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2" >"${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2.idx"

# WMO header (This header is different from WAFS)
cpreq "${FIXwafs}/grib2_gfs_awff${fhr}.45" gfs_wmo_header45

export pgm="${TOCGRIB2}"

# Clean out any existing output files
. prep_step

export FORT11="${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2"
export FORT31=" "
export FORT51="grib2.wafs.t${cyc}z.awf_grid45.f${fhr}"

# For FAA, add WMO header. The header is different from WAFS
${pgm} <gfs_wmo_header45 >>"${pgmout}" 2>errfile
export err=$?
err_chk

# Check if TOCGRIB2 succeeded in creating the output file
if [[ ! -f "${FORT51}" ]]; then
    err_exit "FATAL ERROR: '${pgm}' failed to create '${FORT51}', ABORT!"
fi

if [[ "${wafs_timewindow}" == "YES" ]]; then
    #---------------------------
    # 2) traditional WAFS fields
    #---------------------------
    # 3D data from "./wafs_master.grib2", on exact model pressure levels
    cpreq "${WAFS_MASTER}" ./wafs_master.grib2
    ${WGRIB2} "./wafs_master.grib2" | grep -F -f "${FIXwafs}/grib2_wafs.gfs_master.list" | ${WGRIB2} -i "./wafs_master.grib2" -grib "tmpfile_wafsf${fhr}"
    # 2D data from "./gfs_master.grib2"
    tail -5 "${FIXwafs}/grib2_wafs.gfs_master.list" >grib2_wafs.gfs_master.list.2D
    ${WGRIB2} "./gfs_master.grib2" | grep -F -f grib2_wafs.gfs_master.list.2D | ${WGRIB2} -i "./gfs_master.grib2" -grib "tmpfile_wafsf${fhr}.2D"
    # Complete list of WAFS data
    cat tmpfile_wafsf${fhr}.2D >>tmpfile_wafsf${fhr}

    # U V will have the same grid message number by using -ncep_uv.
    # U V will have the different grid message number without -ncep_uv.
    ${WGRIB2} "tmpfile_wafsf${fhr}" \
        -set master_table 6 \
        -new_grid_winds earth -set_grib_type jpeg \
        -new_grid_interpolation bilinear -if ":(UGRD|VGRD):max wind" -new_grid_interpolation neighbor -fi \
        -new_grid latlon 0:288:1.25 90:145:-1.25 "gfs.t${cyc}z.wafs_grb45f${fhr}.grib2"
    ${WGRIB2} -s "gfs.t${cyc}z.wafs_grb45f${fhr}.grib2" >"gfs.t${cyc}z.wafs_grb45f${fhr}.grib2.idx"

    export pgm="${TOCGRIB2}"

    # WMO header
    cpreq "${FIXwafs}/grib2_wafsf${fhr}.45" wafs_wmo_header45

    # Clean out any existing output files
    . prep_step

    export FORT11="gfs.t${cyc}z.wafs_grb45f${fhr}.grib2"
    export FORT31=" "
    export FORT51="grib2.wafs.t${cyc}z.grid45.f${fhr}"

    # For WAFS, add WMO header. Processing WAFS GRIB2 grid 45 for ISCS and WIFS
    ${pgm} <wafs_wmo_header45 >>"${pgmout}" 2>errfile
    export err=$?
    err_chk

    # Check if TOCGRIB2 succeeded in creating the output file
    if [[ ! -f "${FORT51}" ]]; then
        err_exit "FATAL ERROR: '${pgm}' failed to create '${FORT51}', ABORT!"
    fi

fi # wafs_timewindow

# Send data to COM
if [[ "${SENDCOM}" == "YES" ]]; then

    # FAA data
    cpfs "${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2" "${COMOUT}/${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2"
    cpfs "${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2.idx" "${COMOUT}/${RUN}.t${cyc}z.awf_grid45.f${fhr}.grib2.idx"

    # WAFS data
    if [[ "${wafs_timewindow}" == "YES" ]]; then
        cpfs "gfs.t${cyc}z.wafs_grb45f${fhr}.grib2" "${COMOUT}/gfs.t${cyc}z.wafs_grb45f${fhr}.grib2"
        cpfs "gfs.t${cyc}z.wafs_grb45f${fhr}.grib2.idx" "${COMOUT}/gfs.t${cyc}z.wafs_grb45f${fhr}.grib2.idx"
    fi

    cpfs "grib2.wafs.t${cyc}z.awf_grid45.f${fhr}" "${COMOUTwmo}/grib2.wafs.t${cyc}z.awf_grid45.f${fhr}"

    if [[ "${wafs_timewindow}" == "YES" ]]; then
        cpfs "grib2.wafs.t${cyc}z.grid45.f${fhr}" "${COMOUTwmo}/grib2.wafs.t${cyc}z.grid45.f${fhr}"
    fi
fi

# Alert via DBN
if [[ "${SENDDBN}" == "YES" ]]; then

    # Distribute Data to WOC
    if [[ "${wafs_timewindow}" == "YES" ]]; then
        "${DBNROOT}/bin/dbn_alert" MODEL WAFS_1P25_GB2 "${job}" "${COMOUT}/gfs.t${cyc}z.wafs_grb45f${fhr}.grib2"
        # Distribute Data to TOC TO WIFS FTP SERVER (AWC)
        "${DBNROOT}/bin/dbn_alert" NTC_LOW "${NET}" "${job}" "${COMOUTwmo}/grib2.wafs.t${cyc}z.grid45.f${fhr}"
    fi

    # Distribute data to FAA
    "${DBNROOT}/bin/dbn_alert" NTC_LOW "${NET}" "${job}" "${COMOUTwmo}/grib2.wafs.t${cyc}z.awf_grid45.f${fhr}"

fi

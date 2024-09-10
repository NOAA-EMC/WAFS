#!/bin/bash

######################################################################
#  UTILITY SCRIPT NAME :  exwafs_grib2_0p25.sh
#         DATE WRITTEN :  03/20/2020
#
#  Abstract:  This utility script produces the WAFS GRIB2 at 0.25 degree.
#             The output GRIB files are posted on NCEP ftp server and the
#             grib2 files are pushed via dbnet to TOC to WAFS (ICSC).
#             This is a joint project of WAFC London and WAFC Washington.
#
#             We are processing WAFS grib2 for fhr:
#             hourly: 006 - 024
#             3 hour: 027 - 048
#             6 hour: 054 - 120 (for U/V/T/RH, not for turbulence/icing/CB)
#
#  History:  Mar 2020   - First implementation of this new script.
#            Oct 2021   - Remove jlogfile
#            Aug 2022   - fhr expanded from 36 to 120
#            09/08/2024 - WAFS separation
#              - Filename changes according to EE2 standard except for files sent to UK
#              - dbn_alert subtype is changed from gfs to WAFS
#              - Fix bugzilla 1213: Filename should use fHHH instead of FHH
#              - Add additional levels of icing and turbulence to AWF files
#####################################################################

set -x

GFS_MASTER="${COMINgfs}/gfs.t${cyc}z.master.grb2f${fhr}"
WAFS_MASTER="${COMIN}/${RUN}.t${cyc}z.master.f${fhr}.grib2"

ifhr="$((10#${fhr}))"
if ((ifhr <= 48)); then
    hazard_timewindow="YES"
else
    hazard_timewindow="NO"
fi

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

# WGRIB2 options
opt1=' -set_grib_type same -new_grid_winds earth '
opt21=' -new_grid_interpolation bilinear  -if '
opt22="(:ICESEV|parm=37):"
opt23=' -new_grid_interpolation neighbor -fi '
opt24=' -set_bitmap 1 -set_grib_max_bits 16 '
newgrid="latlon 0:1440:0.25 90:721:-0.25"

# WAFS 3D data
cpreq "${WAFS_MASTER}" ./wafs_master.grib2
${WGRIB2} "./wafs_master.grib2" ${opt1} ${opt21} ${opt22} ${opt23} ${opt24} -new_grid ${newgrid} tmp_wafs_0p25.grb2
# GFS 2D data
cpreq "${GFS_MASTER}" ./gfs_master.grib2
${WGRIB2} "./gfs_master.grib2" | grep -F -f "${FIXwafs}/wafs/grib2_0p25_gfs_master2d.list" |
    ${WGRIB2} -i "./gfs_master.grib2" -set master_table 25 -grib tmp_master.grb2
${WGRIB2} tmp_master.grb2 ${opt1} ${opt21} ":(UGRD|VGRD):max wind" ${opt23} ${opt24} -new_grid ${newgrid} tmp_master_0p25.grb2

#---------------------------
# Product 1: WAFS u/v/t/rh wafs.tHHz.0p25.fFFF.grib2
#---------------------------
${WGRIB2} tmp_wafs_0p25.grb2 | grep -E "UGRD|VGRD|TMP|HGT|RH" |
    ${WGRIB2} -i tmp_wafs_0p25.grb2 -set master_table 25 -grib "tmp.gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2"
cat tmp_master_0p25.grb2 >>"tmp.gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2"
# Convert template 5 to 5.40
#${WGRIB2} "tmp.gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2" -set_grib_type jpeg -grib_out "gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2"
mv "tmp.gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2" "gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2"
${WGRIB2} -s "gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2" >"gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2.idx"

if [[ "${hazard_timewindow}" == "YES" ]]; then
    #---------------------------
    # Product 2: For AWC and Delta airline: EDPARM CAT MWT ICESEV CB  wafs.tHHz.awf.0p25.fFFF.grib2
    #---------------------------
    criteria1=":EDPARM:|:ICESEV:|parm=37:"
    criteria2=":CATEDR:|:MWTURB:"
    criteria3=":CBHE:|:ICAHT:"
    ${WGRIB2} tmp_wafs_0p25.grb2 | grep -E "${criteria1}|$criteria2|$criteria3" |
        ${WGRIB2} -i tmp_wafs_0p25.grb2 -grib "${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2"
    ${WGRIB2} -s "${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2" >"${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2.idx"

    #---------------------------
    # Product 3: WAFS unblended EDPARM, ICESEV, CB (No CAT MWT) wafs.tHHz.unblended.0p25.fFFF.grib2
    #---------------------------
    ${WGRIB2} tmp_wafs_0p25.grb2 | grep -F -f "${FIXwafs}/wafs/grib2_0p25_wafs_hazard.list" |
        ${WGRIB2} -i tmp_wafs_0p25.grb2 -set master_table 25 -grib tmp_wafs_0p25.grb2.forblend

    # Convert template 5 to 5.40
    #${WGRIB2} tmp_wafs_0p25.grb2.forblend -set_grib_type jpeg -grib_out "WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
    mv tmp_wafs_0p25.grb2.forblend "WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
    ${WGRIB2} -s "WAFS_0p25_unblended_$PDY${cyc}f${fhr}.grib2" >"WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx"
fi

# Send data to COM
if [[ "${SENDCOM}" == "YES" ]]; then

    cpfs "gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2" "${COMOUT}/gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2"
    cpfs "gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2.idx" "${COMOUT}/gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2.idx"

    if [[ "${hazard_timewindow}" == "YES" ]]; then
        cpfs "${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2" "${COMOUT}/${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2"
        cpfs "${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2.idx" "${COMOUT}/${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2.idx"

        cpfs "WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2" "${COMOUT}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
        cpfs "WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx" "${COMOUT}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2.idx"
    fi

fi

# Alert via DBN
if [[ "${SENDDBN}" == "YES" ]]; then

    if [[ "${hazard_timewindow}" == "YES" ]]; then
        # Hazard WAFS data (ICESEV EDR CAT MWT on 100mb to 1000mb or on new ICAO levels) sent to AWC and to NOMADS for US stakeholders
        "${DBNROOT}/bin/dbn_alert" MODEL WAFS_AWF.0P25_GB2 "${job}" "${COMOUT}/${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2"

        # Unblended US WAFS data sent to UK for blending, to the same server as 1.25 deg unblended data: wmo/grib2.tCCz.wafs_grb_wifsfFF.45
        "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_UBL_GB2 "${job}" "${COMOUT}/WAFS_0p25_unblended_${PDY}${cyc}f${fhr}.grib2"
    fi

    # WAFS U/V/T/RH data sent to the same server as the unblended data as above
    "${DBNROOT}/bin/dbn_alert" MODEL WAFS_0P25_GB2 "${job}" "${COMOUT}/gfs.t${cyc}z.wafs_0p25.f${fhr}.grib2"

fi

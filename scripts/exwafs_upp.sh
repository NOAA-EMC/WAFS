#!/bin/bash

######################################################################
#  UTILITY SCRIPT NAME :  exwafs_upp.sh
#         DATE WRITTEN :  07/22/2024
#
#  Abstract:  This script runs the offline UPP based on GFS model output
#             and creates the WAFS master grib2 file
#
#  History:  07/22/2024
#               - initial version, for WAFS separation
#               - Add additional levels of icing and turbulence than prior to WAFS separation
#####################################################################

set -x

POSTGRB2TBL=${POSTGRB2TBL:-"${g2tmpl_ROOT}/share/params_grib2_tbl_new"}
MPIRUN=${MPIRUN:-"mpiexec -l -n 126 -ppn 126 --cpu-bind depth --depth 1"}

if [[ "${fhr}" == "anl" ]]; then # Analysis

    VDATE="${PDY}${cyc}"
    ATMINP="${COMINgfs}/gfs.t${cyc}z.atmanl.nc"
    FLXINP="${COMINgfs}/gfs.t${cyc}z.sfcanl.nc"
    PostFlatFile="${PARMwafs}/upp/postxconfig-NT-GFS-WAFS-ANL.txt"

else # Forecast

    VDATE=$(${NDATE} +${fhr} ${PDY}${cyc})
    ATMINP="${COMINgfs}/gfs.t${cyc}z.atmf${fhr}.nc"
    FLXINP="${COMINgfs}/gfs.t${cyc}z.sfcf${fhr}.nc"
    ifhr="$((10#${fhr}))"
    if ((ifhr <= 48)); then
        PostFlatFile="${PARMwafs}/upp/postxconfig-NT-GFS-WAFS.txt"
    else
        PostFlatFile="${PARMwafs}/upp/postxconfig-NT-GFS-WAFS-EXT.txt"
    fi

fi

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

# Copy required inputs to local directory
cpreq "${ATMINP}" ./atmfile
cpreq "${FLXINP}" ./flxfile
cpreq "${POSTGRB2TBL}" .
cpreq "${PostFlatFile}" ./postxconfig-NT.txt
cpreq "${PARMwafs}/upp/nam_micro_lookup.dat" ./eta_micro_lookup.dat
if [[ "${fhr}" != "anl" ]]; then
    cpreq "${PARMwafs}/upp/gtg.config.gfs" gtg.config
    cpreq "${PARMwafs}/upp/gtg_imprintings.txt" gtg_imprintings.txt
fi

# Create the itag file
rm -f itag
cat >itag <<EOF
atmfile
netcdfpara
grib2
${VDATE:0:4}-${VDATE:4:2}-${VDATE:6:2}_${VDATE:8:2}:00:00
GFS
flxfile

&nampgb
  kpo=60,
  po=97720.,94210.,90810.,87510.,84310.,81200.,78190.,75260.,72430.,69680.,67020.,64440.,61940.,59520.,57180.,54920.,52720.,50600.,48550.,46560.,44650.,42790.,41000.,39270.,37600.,35990.,34430.,32930.,31490.,30090.,28740.,27450.,26200.,25000.,23840.,22730.,21660.,20650.,19680.,18750.,17870.,17040.,16240.,15470.,14750.,14060.,13400.,12770.,12170.,11600.,11050.,10530.,10040.,9570.,9120.,8700.,8280.,7900.,7520.,7170.,
  popascal=.true.,
/
EOF
cat itag

# output file from UPP executable
export PGBOUT="wafsfile"

export pgm="wafs_upp.x"

# Clean out any existing output files
. prep_step

${MPIRUN} ${EXECwafs}/${pgm} <itag >>${pgmout} 2>errfile
export err=$?
err_chk

# Check if UPP succeeded in creating the master file
if [[ ! -f "${PGBOUT}" ]]; then
    err_exit "FATAL ERROR: UPP failed to create '${PGBOUT}', ABORT!"
fi

# Copy relevant files to COMOUT
if [[ "${fhr}" == "anl" ]]; then # U/V/T analysis interpolated file for verification (EVS)

    # Interpolate to 0.25-degree grid
    ${WGRIB2} "${PGBOUT}" \
        -set_grib_type same -new_grid_winds earth \
        -new_grid_interpolation bilinear -set_bitmap 1 \
        -new_grid latlon 0:1440:0.25 90:721:-0.25 "${PGBOUT}.0p25"
    export err=$?
    ((err != 0)) && err_exit "FATAL ERROR: 'wgrib2' failed to interpolate '${PGBOUT}' to 0.25-deg grid, ABORT!"

    # Copy interpolated file to COMOUT and index the file
    if [[ "${SENDCOM}" == "YES" ]]; then
        cpfs "${PGBOUT}.0p25" "${COMOUT}/${RUN}.t${cyc}z.0p25.anl.grib2"
        ${WGRIB2} -s "${PGBOUT}.0p25" >"${COMOUT}/${RUN}.t${cyc}z.0p25.anl.grib2.idx"
    fi

else # Forecast WAFS master files (including hazard aviation data if forecast hour is 48 or less)

    # Copy master files to COMOUT and index the file
    if [[ "${SENDCOM}" == "YES" ]]; then
        cpfs "${PGBOUT}" "${COMOUT}/${RUN}.t${cyc}z.master.f${fhr}.grib2"
        ${WGRIB2} -s "${PGBOUT}" >"${COMOUT}/${RUN}.t${cyc}z.master.f${fhr}.grib2.idx"
    fi
fi

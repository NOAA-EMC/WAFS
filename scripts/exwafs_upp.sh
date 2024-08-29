#!/bin/bash

#####################################################################
# TODO: need ex-script docblock, see Implementation Standards
#####################################################################
set -x

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

if [[ "${fhr}" == "anl" ]]; then # Analysis

    VDATE="${PDY}${cyc}"
    KPO=56
    PO="84310.,81200.,78190.,75260.,72430.,69680.,67020.,64440.,61940.,59520.,57180.,54920.,52720.,50600.,48550.,46560.,44650.,42790.,41000.,39270.,37600.,35990.,34430.,32930.,31490.,30090.,28740.,27450.,26200.,25000.,23840.,22730.,21660.,20650.,19680.,18750.,17870.,17040.,16240.,15470.,14750.,14060.,13400.,12770.,12170.,11600.,11050.,10530.,10040.,9570.,9120.,8700.,8280.,7900.,7520.,7170."
    ATMINP="${COMINgfs}/gfs.t${cyc}z.atmanl.nc"
    FLXINP="${COMINgfs}/gfs.t${cyc}z.sfcanl.nc"
    PostFlatFile="${PARMwafs}/upp/postxconfig-NT-GFS-WAFS-ANL.txt"

else # Forecast

    VDATE=$(${NDATE} +${fhr} ${PDY}${cyc})
    KPO=58
    PO="97720.,90810.,84310.,81200.,78190.,75260.,72430.,69680.,67020.,64440.,61940.,59520.,57180.,54920.,52720.,50600.,48550.,46560.,44650.,42790.,41000.,39270.,37600.,35990.,34430.,32930.,31490.,30090.,28740.,27450.,26200.,25000.,23840.,22730.,21660.,20650.,19680.,18750.,17870.,17040.,16240.,15470.,14750.,14060.,13400.,12770.,12170.,11600.,11050.,10530.,10040.,9570.,9120.,8700.,8280.,7900.,7520.,7170."
    ATMINP="${COMINgfs}/gfs.t${cyc}z.atmf${fhr}.nc"
    FLXINP="${COMINgfs}/gfs.t${cyc}z.sfcf${fhr}.nc"
    ifhr="$((10#${fhr}))"
    if ((ifhr <= 48)); then
        PostFlatFile="${PARMwafs}/upp/postxconfig-NT-GFS-WAFS.txt"
    else
        PostFlatFile="${PARMwafs}/upp/postxconfig-NT-GFS-WAFS-EXT.txt"
    fi

fi

# Create the itag file
cat >itag <<EOF
atmfile
netcdfpara
grib2
${VDATE:0:4}-${VDATE:4:2}-${VDATE:6:2}_${VDATE:8:2}:00:00
GFS
flxfile
&nampgb
  kpo=${KPO},
  po=${PO},
  popascal=.true.,
/
EOF

cat itag

# Copy required inputs to local directory
cpreq "${ATMINP}" ./atmfile
cpreq "${FLXINP}" ./flxfile
cpreq "${POSTGRB2TBL}" .
cpreq "${PostFlatFile}" ./postxconfig-NT.txt
cpreq "${PARMwafs}/upp/nam_micro_lookup.dat" ./eta_micro_lookup.dat
cpreq "${UPPEXEC}" .

if [[ "${fhr}" != "anl" ]]; then
    cpreq "${PARMwafs}/upp/gtg.config.gfs" gtg.config
    cpreq "${PARMwafs}/upp/gtg_imprintings.txt" gtg_imprintings.txt
fi

# output file from UPP executable
export PGBOUT="wafsfile"

pgm=$(basename "${UPPEXEC}")
export pgm

# Clean out any existing output files
. prep_step

${MPIRUN} ${DATA}/${pgm} <itag >>${pgmout} 2>errfile
export err=$?
err_chk

if [[ -f "${PGBOUT}" ]]; then
    if [[ "${SENDCOM}" == "YES" ]]; then
        cpfs "${PGBOUT}" "${COMOUT}/${RUN}.t${cyc}z.master.f${fhr}.grib2"
        "${WGRIB2}" -s "${PGBOUT}" >"${COMOUT}/${RUN}.t${cyc}z.master.f${fhr}.grib2.idx"
    fi
else
    err_exit "FATAL ERROR: '${PGBOUT}' was not generated, ABORT!"
fi

if [[ "${fhr}" == "anl" ]]; then
    "${WGRIB2}" "${PGBOUT}" \
        -set_grib_type same -new_grid_winds earth \
        -new_grid_interpolation bilinear -set_bitmap 1 \
        -new_grid latlon 0:1440:0.25 90:721:-0.25 "${PGBOUT}.0p25"
    export err=$?
    ((err != 0)) && err_exit "FATAL ERROR: 'wgrib2' failed to interpolate '${PGBOUT}' to 0.25-deg grid, ABORT!"

    if [[ "${SENDCOM}" == "YES" ]]; then
        cpfs "${PGBOUT}.0p25" "${COMOUT}/${RUN}.t${cyc}z.0p25.anl.grib2"
        "${WGRIB2}" -s "${PGBOUT}.0p25" >"${COMOUT}/${RUN}.t${cyc}z.0p25.anl.grib2.idx"
    fi
fi

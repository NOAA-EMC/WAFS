!/bin/bash

######################################################################
#  UTILITY SCRIPT NAME :  exwafs_gefs_upp.sh
#         DATE WRITTEN :  08/12/2026
#
#  Abstract:  This script runs the offline UPP based on GEFS model output
#             and creates the WAFS master grib2 files for each member and
#             each forecast hour
#
#  History:  08/12/2026
#               - initial version
#####################################################################

set -x

POSTGRB2TBL=${POSTGRB2TBL:-"${g2tmpl_ROOT}/share/params_grib2_tbl_new"}
PostFlatFile="${PARMwafs}/upp/postxconfig-NT-gefs-wafs.txt"

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

# Copy required files to local directory
cpreq "${POSTGRB2TBL}" .
cpreq "${PostFlatFile}" ./postxconfig-NT.txt

cpreq "${PARMwafs}/upp/gtg.input.${RUN}" gtg.input.${RUN}
cpreq "${PARMwafs}/upp/gtg.config.${RUN}" gtg.config.${RUN}
cpreq "${PARMwafs}/upp/imprintings.gtg_${RUN}.txt" imprintings.gtg_${RUN}.txt

VDATE=$(${NDATE} +${fhr} ${PDY}${cyc})
ATMINP="${COMINgefs}/${RUNMEM}.t${cyc}z.atmf$fhr.nemsio"
FLXINP="${COMINgefs}/${RUNMEM}.t${cyc}z.sfcf$fhr.nemsio"

# Copy required inputs to local directory
cpreq "${ATMINP}" ./atmfile
cpreq "${FLXINP}" ./flxfile

# Create the itag file
nampgb_suffix="gtg_on=.true., popascal=.true., numx=1"
cat >itag <<EOF
&model_inputs
fileName="atmfile"
IOFORM="binarynemsiompiio"
grib="grib2"
DateStr="${VDATE:0:4}-${VDATE:4:2}-${VDATE:6:2}_${VDATE:8:2}:00:00"
MODELNAME="GFS"
SUBMODELNAME="GEFS"
fileNameFlux="flxfile"
/
&NAMPGB
  kpo=10,
  po=84310.,69680.,59520.,50600.,39270.,34430.,30090.,25000.,19680.,14750.,
  $nampgb_suffix
/
EOF
cat itag

# output file from UPP executable
export PGBOUT="${RUNMEM}.t${cyc}z.master.f${fhr}.grib2"

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

# Copy master files to COMOUT
if [[ "${SENDCOM}" == "YES" ]]; then
    cpfs ${PGBOUT} ${COMOUT}/.
    ${WGRIB2} -s "${PGBOUT}" >"${COMOUT}/${PGBOUT}.idx"
fi

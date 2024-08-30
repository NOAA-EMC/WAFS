#!/bin/bash

######################################################################
#  UTILITY SCRIPT NAME :  exwafs_gcip.sh
#         DATE WRITTEN :  01/28/2015
#
#  Abstract:  This utility script produces the WAFS GCIP.
#
#            GCIP runs f000 f003 for each cycle, 4 times/day,
#            to make the output valid every 3 hours
#
# History:  01/28/2015
#         - GFS master file as first guess
#              /com/prod/gfs.YYYYMMDD
#         - Nesdis composite global satellite data
#              /dcom (ftp?)
#         - Metar/ships/lightning/pireps
#              dumpjb YYYYMMDDHH hours output >/dev/null
#         - Radar data over CONUS
#              /com/hourly/prod/radar.YYYYMMDD/refd3d.tHHz.grbf00
#         - output of current icing potential
#         - First implementation of this new script."
#         Oct 2021 - Remove jlogfile
#         May 2024 - WAFS separation
#####################################################################

set -x

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

# valid time. no worry, it won't be across to another date
vhour=$((fhr + cyc))
vhour="$(printf "%02d" $((10#$vhour)))"

# metar / ships / lightning / pireps
export TMPDIR="${DATA}" # dumpjb uses TMPDIR
obsfiles="metar ships ltngsr pirep"
for obsfile in ${obsfiles}; do
	${DUMPJB} "${PDY}${vhour}" 1.5 "${obsfile}"
done

# dumped data files suffix is ".ibm"
metarFile="metar.ibm"
shipFile="ships.ibm"
lightningFile="ltngsr.ibm"
pirepFile="pirep.ibm"

# Setup mailing list once
if [[ "${envir}" != "prod" ]]; then
	maillist="nco.spa@noaa.gov"
fi
maillist=${maillist:-"nco.spa@noaa.gov,ncep.sos@noaa.gov"}

satFiles=""
channels="VIS SIR LIR SSR"
# If one channel is missing, satFiles will be empty
for channel in ${channels}; do
	satFile="GLOBCOMP${channel}.${PDY}${vhour}"
	if [[ "${COMINsat}" == *ftp:* ]]; then
		curl -O "${COMINsat}/${satFile}"
	else
		# check the availability of satellite data file
		if [[ -s "${COMINsat}/${satFile}" ]]; then
			cpreq "${COMINsat}/${satFile}" .
		else
			msg="GCIP at ${vhour}z ABORTING, no satellite ${channel} file!"
			echo "${msg}"
			echo "${msg}" >>"${COMOUT}/${RUN}.gcip.log"

			subject="Missing GLOBCOMPVIS Satellite Data for ${PDY} t${cyc}z ${job}"
			echo "*************************************************************" >mailmsg
			echo "*** WARNING !! COULD NOT FIND GLOBCOMPVIS Satellite Data  *** " >>mailmsg
			echo "*************************************************************" >>mailmsg
			echo >>mailmsg
			echo "One or more GLOBCOMPVIS Satellite Data files are missing, including " >>mailmsg
			echo "   ${COMINsat}/${satFile} " >>mailmsg
			echo >>mailmsg
			echo "${job} will gracfully exit" >>mailmsg
			cat mailmsg >"${COMOUT}/${RUN}.t${cyc}z.gcip.emailbody"
			cat "${COMOUT}/${RUN}.t${cyc}z.gcip.emailbody" | mail.py -s "${subject}" "${maillist}" -v

			exit 1
		fi
	fi
	if [[ -s "${satFile}" ]]; then
		satFiles="${satFiles} ${satFile}"
	else
		satFiles=""
		break
	fi
done

# Copy GFS master file and prepare modelFile
cpreq "${COMINgfs}/gfs.t${cyc}z.master.grb2f${fhr}" ./gfs_master.grib2
modelFile="modelfile.grb"
${WGRIB2} "gfs_master.grib2" | grep -E ":HGT:|:VVEL:|:CLWMR:|:TMP:|:SPFH:|:RWMR:|:SNMR:|:GRLE:|:ICMR:|:RH:" | grep -E "00 mb:|25 mb:|50 mb:|75 mb:|:HGT:surface" | ${WGRIB2} -i "gfs_master.grib2" -grib "${modelFile}"

# Composite gcip command options
configFile="gcip.config"
cmdoptions="-t ${PDY}${vhour} -c ${configFile} -model ${modelFile}"
if [[ -s "${metarFile}" ]]; then
	cmdoptions="${cmdoptions} -metar ${metarFile}"
else
	err_exit "FATAL ERROR: There are no METAR observations."
fi
if [[ -s "${shipFile}" ]]; then
	cmdoptions="${cmdoptions} -ship ${shipFile}"
else
	echo "WARNING: There are no SHIP observations"
fi
# empty if a channel data is missing
if [[ -n "${satFiles}" ]]; then
	cmdoptions="${cmdoptions} -sat ${satFiles}"
else
	err_exit "FATAL ERROR: Satellite data are not available or completed."
fi
if [[ -s "${lightningFile}" ]]; then
	cmdoptions="${cmdoptions} -lightning ${lightningFile}"
fi
if [[ -s "${pirepFile}" ]]; then
	cmdoptions="${cmdoptions} -pirep ${pirepFile}"
else
	echo "WARNING: There are no PIREP observations"
fi
# radar data
sourceRadar="${COMINradar}/refd3d.t${vhour}z.grb2f00"
radarFile="radarFile.grb"
if [[ -s "${sourceRadar}" ]]; then
	cpreq "${sourceRadar}" "${radarFile}"
	cmdoptions="${cmdoptions} -radar ${radarFile}"
else
	echo "WARNING: There are no RADAR observations"
fi

outputfile="wafs.t${vhour}z.gcip.f000.grib2"
cmdoptions="${cmdoptions} -o ${outputfile}"

# Copy the configuration files and the executable
cpreq "${PARMwafs}/wafs_gcip_gfs.cfg" "${configFile}"
cpreq "${FIXwafs}/gcip_near_ir_refl.table" ./near_ir_refl.table
cpreq "${EXECwafs}/wafs_gcip.x" ./wafs_gcip.x

export pgm="wafs_gcip.x"

. prep_step

${pgm}${cmdoptions} >>"${pgmout}" 2>errfile
export err=$?
err_chk

if [[ ! -f "${outputfile}" ]]; then
	err_exit "FATAL ERROR: '${pgm}' failed to produce output '${outputfile}', ABORT!"
fi

# Send output to COM
if [[ "${SENDCOM}" == "YES" ]]; then
	cpfs "${outputfile}" "${COMOUT}/${outputfile}"
fi

# Alert through DBN
if [[ "${SENDDBN}" == "YES" ]]; then
	echo "TODO: DBN alert missing..."
fi

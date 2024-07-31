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
#              ksh /nwprod/ush/dumpjb YYYYMMDDHH hours output >/dev/null
#         - Radar data over CONUS
#              /com/hourly/prod/radar.YYYYMMDD/refd3d.tHHz.grbf00
#         - output of current icing potential
#####################################################################
echo "-----------------------------------------------------"
echo "JWAFS_GCIP at 00Z/06Z/12Z/18Z GFS postprocessing"
echo "-----------------------------------------------------"
echo "History: 2015 - First implementation of this new script."
echo "Oct 2021 - Remove jlogfile"
echo "May 2024 - WAFS separation"
echo " "
#####################################################################

set -x

# Set up working dir for parallel runs based on fhr
fhr=$1
DATA=$DATA/$fhr
mkdir -p $DATA
cd $DATA
# Overwrite TMPDIR for dumpjb
export TMPDIR=$DATA

configFile=gcip.config

echo 'before preparing data' `date`

# valid time. no worry, it won't be across to another date
vhour=$(( $fhr + $cyc ))
vhour="$(printf "%02d" $(( 10#$vhour )) )"

########################################################
# Preparing data

# model data
masterFile=$COMINgfs/gfs.t${cyc}z.master.grb2f$fhr
cp $PARMwafs/wafs_gcip_gfs.cfg $configFile

modelFile=modelfile.grb
#  ln -sf $masterFile $modelFile
$WGRIB2 $masterFile | egrep ":HGT:|:VVEL:|:CLWMR:|:TMP:|:SPFH:|:RWMR:|:SNMR:|:GRLE:|:ICMR:|:RH:" | egrep "00 mb:|25 mb:|50 mb:|75 mb:|:HGT:surface" | $WGRIB2 -i $masterFile -grib $modelFile

# metar / ships / lightning / pireps
# dumped data files' suffix is ".ibm"
obsfiles="metar ships ltngsr pirep"
for obsfile in $obsfiles ; do 
#      ksh $USHobsproc_dump/dumpjb ${PDY}${vhour} 1.5 $obsfile >/dev/null
    ksh $DUMPJB ${PDY}${vhour} 1.5 $obsfile 
done
metarFile=metar.ibm
shipFile=ships.ibm
lightningFile=ltngsr.ibm
pirepFile=pirep.ibm

satFiles=""
channels="VIS SIR LIR SSR"
# If one channel is missing, satFiles will be empty
for channel in $channels ; do
    satFile=GLOBCOMP$channel.${PDY}${vhour}
    if [[ $COMINsat == *ftp:* ]] ; then
	curl -O $COMINsat/$satFile
    else
        # check the availability of satellite data file
	if [ -s $COMINsat/$satFile ] ; then
	    cp $COMINsat/$satFile .
	else
	    msg="GCIP at ${vhour}z ABORTING, no satellite $channel file!"
	    echo "$msg"
	    echo $msg >> $COMOUT/${RUN}.gcip.log
            
	    if [ $envir != prod ]; then
		export maillist='nco.spa@noaa.gov'
	    fi
	    export maillist=${maillist:-'nco.spa@noaa.gov,ncep.sos@noaa.gov'}

	    export subject="Missing GLOBCOMPVIS Satellite Data for $PDY t${cyc}z $job"
	    echo "*************************************************************" > mailmsg
	    echo "*** WARNING !! COULD NOT FIND GLOBCOMPVIS Satellite Data  *** " >> mailmsg
	    echo "*************************************************************" >> mailmsg
	    echo >> mailmsg
	    echo "One or more GLOBCOMPVIS Satellite Data files are missing, including " >> mailmsg
	    echo "   $COMINsat/$satFile " >> mailmsg
	    echo >> mailmsg
	    echo "$job will gracfully exited" >> mailmsg
	    cat mailmsg > $COMOUT/${RUN}.t${cyc}z.gcip.emailbody
	    cat $COMOUT/${RUN}.t${cyc}z.gcip.emailbody | mail.py -s "$subject" $maillist -v

	    exit 1
	fi
    fi
    if [[ -s $satFile ]] ; then
	satFiles="$satFiles $satFile"
    else
	satFiles=""
	break
    fi
done

# radar data
sourceRadar=$COMINradar/refd3d.t${vhour}z.grb2f00
radarFile=radarFile.grb
if [ -s $sourceRadar ] ; then
    cp $sourceRadar $radarFile
fi

########################################################
# Composite gcip command options

outputfile=wafs.t${vhour}z.gcip.f000.grib2

cmdoptions="-t ${PDY}${vhour} -c $configFile -model $modelFile"
if [[ -s $metarFile ]] ; then
    cmdoptions="$cmdoptions -metar $metarFile"
else
    err_exit "There are no METAR observations."
fi
if [[ -s $shipFile ]] ; then
    cmdoptions="$cmdoptions -ship $shipFile"
fi
# empty if a channel data is missing
if [[ -n $satFiles ]] ; then
    cmdoptions="$cmdoptions -sat $satFiles"
else
    err_exit "Satellite data are not available or completed."
fi
if [[ -s $lightningFile ]] ; then
    cmdoptions="$cmdoptions -lightning $lightningFile"
fi
if [[ -s $pirepFile ]] ; then
    cmdoptions="$cmdoptions -pirep $pirepFile"
fi
if [[ -s $radarFile ]] ; then
    cmdoptions="$cmdoptions -radar $radarFile"
fi
cmdoptions="$cmdoptions -o $outputfile"

#######################################################
# Run GCIP

echo 'after preparing data' `date`

export pgm=wafs_gcip.x

cp $FIXwafs/gcip_near_ir_refl.table near_ir_refl.table

startmsg
$EXECwafs/$pgm >> $pgmout $cmdoptions 2> errfile &
wait
export err=$?; err_chk


if [[ -s $outputfile ]] ; then
    ############################## 
    # Post Files to COM
    ##############################
    if [ $SENDCOM = "YES" ] ; then
      cp $outputfile $COMOUT/$outputfile
      if [ $SENDDBN = "YES" ] ; then
	  :
      fi
    fi
else
    err_exit "Output $outputfile was not generated"
fi


################################################################################
# GOOD RUN
set +x
echo "**************JOB EXWAFS_GCIP.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXWAFS_GCIP.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXWAFS_GCIP.SH COMPLETED NORMALLY ON THE IBM"
set -x
################################################################################

exit 0

############## END OF SCRIPT #######################


#!/bin/bash

################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exwafs_grib2_0p25_blending.sh
# Script description:  This scripts looks for US and UK WAFS Grib2 products at 1/4 deg,
# wait for specified period of time. If both WAFS data are available.
# Otherwise, the job aborts with error massage
#
# Author:        Y Mao       Org: EMC         Date: 2020-04-02
#
#
# Script history log:
# 2020-04-02 Y Mao
# Oct 2021 - Remove jlogfile
# 2022-05-25 | Y Mao | Add ICAO new milestone Nov 2023
# May 2024 - WAFS separation

set -x
echo "JOB $job HAS BEGUN"
export SEND_AWC_US_ALERT=NO
export SEND_AWC_UK_ALERT=NO
export SEND_US_WAFS=NO
export SEND_UK_WAFS=NO

YYYY=`echo $PDY | cut -c1-4`
MM=`echo $PDY | cut -c5-6`
DD=`echo $PDY | cut -c7-8`

cd $DATA
export SLEEP_LOOP_MAX=`expr $SLEEP_TIME / $SLEEP_INT`

echo "start blending US and UK WAFS products at 1/4 degree for " $cyc " z cycle"

export ic_uk=1

fhr="$(printf "%03d" $(( 10#$fhr )) )"
##########################
# look for US WAFS data
##########################

export ic=1
while [ $ic -le $SLEEP_LOOP_MAX ]
do 
    if [ -s ${COMINus}/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2 ] ; then
        break
    fi
    if [ $ic -eq $SLEEP_LOOP_MAX ] ; then
        echo "US WAFS GRIB2 file  $COMINus/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2 not found after waiting over $SLEEP_TIME seconds"
	echo "US WAFS GRIB2 file " $COMINus/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2 "not found after waiting ",$SLEEP_TIME, "exitting"
	SEND_UK_WAFS=YES
	break
    else
	ic=`expr $ic + 1`
	sleep $SLEEP_INT
    fi
done

##########################
# look for UK WAFS data.
##########################

SLEEP_LOOP_MAX_UK=$SLEEP_LOOP_MAX
     
#  export ic=1
while [ $ic_uk -le $SLEEP_LOOP_MAX_UK ]
do
    # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
    #ukfiles=`ls $COMINuk/EGRR_WAFS_0p25_*_unblended_${PDY}_${cyc}z_t${fhr2}.grib2 | wc -l`
    ukfiles=`ls $COMINuk/egrr_wafshzds_unblended_*_0p25_${YYYY}-${MM}-${DD}T${cyc}:00Z_t$fhr.grib2 | wc -l`
    if [ $ukfiles -ge 3 ] ; then
        break
    fi

    if [ $ic_uk -eq $SLEEP_LOOP_MAX_UK ] ; then
	echo "UK WAFS GRIB2 file " $COMINuk/egrr_wafshzds_unblended_*_0p25_${YYYY}-${MM}-${DD}T${cyc}:00Z_t$fhr.grib2 " not found"
        export SEND_US_WAFS=YES
	break
    else
        ic_uk=`expr $ic_uk + 1`
        sleep $SLEEP_INT
    fi
done

##########################
# If both UK and US data are missing.
##########################

if [ $SEND_UK_WAFS = 'YES' -a $SEND_US_WAFS = 'YES' ] ; then
    SEND_US_WAFS=NO
    SEND_UK_WAFS=NO
    echo "BOTH UK and US data are missing, no blended for $PDY$cyc$fhr"
    export err=1; err_chk
    continue
fi
 
##########################
# Blending or unblended
##########################

if [ $SEND_US_WAFS = 'YES' ] ; then
    echo "turning back on dbn alert for unblended US WAFS product"
elif [ $SEND_UK_WAFS = 'YES' ] ; then
    echo "turning back on dbn alert for unblended UK WAFS product"
    # retrieve UK products
    # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
    cat $COMINuk/egrr_wafshzds_unblended_*_0p25_${YYYY}-${MM}-${DD}T${cyc}:00Z_t$fhr.grib2 > EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2
else # elif [ $SEND_US_WAFS = "NO" -a $SEND_UK_WAFS = "NO" ] ; then
    # retrieve UK products
    # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
    cat $COMINuk/egrr_wafshzds_unblended_*_0p25_${YYYY}-${MM}-${DD}T${cyc}:00Z_t$fhr.grib2 > EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2
    
    # pick up US data
    cp ${COMINus}/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2 .

    # run blending code
    export pgm=wafs_blending_0p25.x
    . prep_step

    startmsg
    $EXECwafs/$pgm wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2 \
                   EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2 \
                   0p25_blended_${PDY}${cyc}f${fhr}.grib2 > f${fhr}.out

    err1=$?
    if test "$err1" -ne 0
    then
	echo "WAFS blending 0p25 program failed at " ${PDY}${cyc}F${fhr} " turning back on dbn alert for unblended US WAFS product"
	SEND_US_WAFS=YES
    fi
fi

##########################
# Date dissemination
##########################

if [ $SEND_US_WAFS = "YES" ] ; then

    ##############################################################################################
    #
    #  checking any US WAFS product was sent due to No UK WAFS GRIB2 file or WAFS blending program
    #  (Alert once for all forecast hours)
    #
    if [ $SEND_AWC_US_ALERT = "NO" ] ; then
	echo "WARNING! No UK WAFS GRIB2 0P25 file for WAFS blending. Send alert message to AWC ......"
	make_NTC_file.pl NOXX10 KKCI $PDY$cyc NONE $FIXwafs/wafs_blending_0p25_admin_msg $PCOM/wifs_0p25_admin_msg
	make_NTC_file.pl NOXX10 KWBC $PDY$cyc NONE $FIXwafs/wafs_blending_0p25_admin_msg $PCOM/iscs_0p25_admin_msg
	if [ $SENDDBN_NTC = "YES" ] ; then
	    $DBNROOT/bin/dbn_alert NTC_LOW WAFS  $job $PCOM/wifs_0p25_admin_msg
	    $DBNROOT/bin/dbn_alert NTC_LOW WAFS  $job $PCOM/iscs_0p25_admin_msg
	fi

        if [ $envir != prod ]; then
	    export maillist='nco.spa@noaa.gov'
        fi
        export maillist=${maillist:-'nco.spa@noaa.gov,ncep.sos@noaa.gov'}
        export subject="WARNING! No UK WAFS GRIB2 0P25 file for WAFS blending, $PDY t${cyc}z $job"
        echo "*************************************************************" > mailmsg
        echo "*** WARNING! No UK WAFS GRIB2 0P25 file for WAFS blending ***" >> mailmsg
        echo "*************************************************************" >> mailmsg
        echo >> mailmsg
        echo "Send alert message to AWC ...... " >> mailmsg
        echo >> mailmsg
        cat mailmsg > $COMOUT/${RUN}.t${cyc}z.wafs_blend_0p25_usonly.emailbody
        cat $COMOUT/${RUN}.t${cyc}z.wafs_blend_0p25_usonly.emailbody | mail.py -s "$subject" $maillist -v

	export SEND_AWC_US_ALERT=YES
    fi
    ##############################################################################################
    #
    #   Distribute US WAFS unblend Data to NCEP FTP Server (WOC) and TOC
    #
    echo "altering the unblended US WAFS products - $COMINus/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2 "
    echo "and $COMINus/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2.idx "

    if [ $SENDDBN = "YES" ] ; then
	$DBNROOT/bin/dbn_alert MODEL WAFS_0P25_UBL_GB2 $job $COMINus/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2
	$DBNROOT/bin/dbn_alert MODEL WAFS_0P25_UBL_GB2_WIDX $job $COMINus/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2.idx
    fi

#	 if [ $SENDDBN_NTC = "YES" ] ; then
#	     $DBNROOT/bin/dbn_alert NTC_LOW $NET $job $COMOUT/wafs.t${cyc}z.unblended.0p25.f${fhr}.grib2
#	 fi


    export SEND_US_WAFS=NO

elif [ $SEND_UK_WAFS = "YES" ] ; then
    ##############################################################################################
    #
    #  checking any UK WAFS product was sent due to No US WAFS GRIB2 file
    #  (Alert once for all forecast hours)
    #
    if [ $SEND_AWC_UK_ALERT = "NO" ] ; then
	echo "WARNING: No US WAFS GRIB2 0P25 file for WAFS blending. Send alert message to AWC ......"
	make_NTC_file.pl NOXX10 KKCI $PDY$cyc NONE $FIXwafs/wafs_blending_0p25_admin_msg $PCOM/wifs_0p25_admin_msg
	make_NTC_file.pl NOXX10 KWBC $PDY$cyc NONE $FIXwafs/wafs_blending_0p25_admin_msg $PCOM/iscs_0p25_admin_msg
	if [ $SENDDBN_NTC = "YES" ] ; then
	    $DBNROOT/bin/dbn_alert NTC_LOW WAFS  $job $PCOM/wifs_0p25_admin_msg
		 $DBNROOT/bin/dbn_alert NTC_LOW WAFS  $job $PCOM/iscs_0p25_admin_msg
	fi

        if [ $envir != prod ]; then
            export maillist='nco.spa@noaa.gov'
        fi
        export maillist=${maillist:-'nco.spa@noaa.gov,ncep.sos@noaa.gov'}
        export subject="WARNING! No US WAFS GRIB2 0P25 file for WAFS blending, $PDY t${cyc}z $job"
        echo "*************************************************************" > mailmsg
        echo "*** WARNING! No US WAFS GRIB2 0P25 file for WAFS blending ***" >> mailmsg
        echo "*************************************************************" >> mailmsg
        echo >> mailmsg
        echo "Send alert message to AWC ...... " >> mailmsg
        echo >> mailmsg
        cat mailmsg > $COMOUT/${RUN}.t${cyc}z.wafs_blend_0p25_ukonly.emailbody
        cat $COMOUT/${RUN}.t${cyc}z.wafs_blend_0p25_ukonly.emailbody | mail.py -s "$subject" $maillist -v
	     
	export SEND_AWC_UK_ALERT=YES
    fi
    ##############################################################################################
    #
    #   Distribute UK WAFS unblend Data to NCEP FTP Server (WOC) and TOC
    #
    echo "altering the unblended UK WAFS products - EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2"

    if [ $SENDDBN = "YES" ] ; then
	$DBNROOT/bin/dbn_alert MODEL WAFS_UKMET_0P25_UBL_GB2 $job EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2
    fi

#	 if [ $SENDDBN_NTC = "YES" ] ; then
#	     $DBNROOT/bin/dbn_alert NTC_LOW $NET $job EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${fhr}.grib2
#	 fi
    export SEND_UK_WAFS=NO


else
    ##############################################################################################
    #
    # TOCGRIB2 Processing WAFS Blending GRIB2 (Icing, CB, GTG)

    # As in August 2020, no WMO header is needed for WAFS data at 1/4 deg
    ## . prep_step
    ## export pgm=$TOCGRIB2
    ## startmsg

    ## export FORT11=0p25_blended_${PDY}${cyc}f${fhr}.grib2
    ## export FORT31=" "
    ## export FORT51=grib2.t${cyc}z.WAFS_0p25_blended_f${fhr}

    ## $TOCGRIB2 <  $FIXwafs/grib2_blended_wafs_wifs_f${fhr}.0p25 >> $pgmout 2> errfile

    ## err=$?;export err ;err_chk
    ## echo " error from tocgrib=",$err

    ##############################################################################################
    #
    #   Distribute US WAFS unblend Data to NCEP FTP Server (WOC) and TOC
    #
    if [ $SENDCOM = YES ]; then
	cp 0p25_blended_${PDY}${cyc}f${fhr}.grib2 $COMOUT/wafs.t${cyc}z.blended.0p25.f${fhr}.grib2
	## cp grib2.t${cyc}z.WAFS_0p25_blended_f${fhr}  $PCOM/grib2.t${cyc}z.WAFS_0p25_blended_f${fhr}
    fi

    if [ $SENDDBN_NTC = "YES" ] ; then
	#   Distribute Data to NCEP FTP Server (WOC) and TOC
	echo "No WMO header yet"
	## $DBNROOT/bin/dbn_alert NTC_LOW $NET $job $PCOM/grib2.t${cyc}z.WAFS_0p25_blended_f${fhr}
    fi

    if [ $SENDDBN = "YES" ] ; then
	$DBNROOT/bin/dbn_alert MODEL WAFS_0P25_BL_GB2 $job $COMOUT/wafs.t${cyc}z.blended.0p25.f${fhr}.grib2
    fi 
fi

################################################################################

exit 0
#

#!/bin/ksh
#######################################################################
#########
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:        wafs_blending_0p25.sh (copied from wafs_blending.sh) 
# Script description:  this script retrieves US and UK WAFS Grib2 products 
# at 1/4 DEG, performs blending, and then writes the new blended products
# in Grib2 to a new Grib file
#
# Author:        Y Mao       Org: EMC         Date: 2020-04-10
#
# Script history log:
# 2020-04-10  Y Mao
#


set -x

cd $DATA

if [ $SEND_US_WAFS = "NO" ] ; then

  # retrieve UK products

  # Three(3) unblended UK files for each cycle+fhour: icing, turb, cb
  cat $COMINuk/EGRR_WAFS_0p25_*_unblended_${PDY}_${cyc}z_t${ffhr}.grib2 > EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${ffhr}.grib2

  # pick up US data

  cp ${COMINus}/gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr}.grib2 .

  # run blending code
  startmsg
  $EXECgfs/wafs_blending_0p25 gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr}.grib2 \
                              EGRR_WAFS_0p25_unblended_${PDY}_${cyc}z_t${ffhr}.grib2 \
                              0p25_blended_${PDY}${cyc}f${ffhr}.grib2 > f${ffhr}.out

  err1=$?
  if test "$err1" -ne 0
  then
      echo "WAFS blending 0p25 program failed at " ${PDY}${cyc}F${ffhr} " turning back on dbn alert for unblended US WAFS product"
      SEND_US_WAFS=YES
  fi
fi

if [ $SEND_US_WAFS = "YES" ] ; then

##############################################################################################
#
#  checking any US WAFS product was sent due to No UK WAFS GRIB2 file or WAFS blending program
#
   if [ $SEND_US_WAFS = "YES" -a $SEND_AWC_ALERT = "NO" ] ; then
      msg="No UK WAFS GRIB2 0P25 file or WAFS blending program. Send alert message to AWC ......"
      postmsg "$jlogfile" "$msg"
      make_NTC_file.pl NOXX10 KKCI $PDY$cyc NONE $FIXgfs/wafs_0p25_admin_msg $PCOM/wifs_0p25_admin_msg
      make_NTC_file.pl NOXX10 KWBC $PDY$cyc NONE $FIXgfs/wafs_0p25_admin_msg $PCOM/iscs_0p25_admin_msg
      if [ $SENDDBN_NTC = "YES" ] ; then
           $DBNROOT/bin/dbn_alert NTC_LOW WAFS  $job $PCOM/wifs_0p25_admin_msg
           $DBNROOT/bin/dbn_alert NTC_LOW WAFS  $job $PCOM/iscs_0p25_admin_msg
      fi
      export SEND_AWC_ALERT=YES
   fi
##############################################################################################
 #
 #   Distribute US WAFS unblend Data to NCEP FTP Server (WOC) and TOC
 #
   echo "altering the unblended US WAFS products - $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2 "
   echo "and $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2.idx "
   echo "and $PCOM/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2 "

   if [ $SENDDBN = "YES" -a $SEND_US_WAFS = "YES" ] ; then
      $DBNROOT/bin/dbn_alert MODEL GFS_WAFSA_GB2 $job $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2
      $DBNROOT/bin/dbn_alert MODEL GFS_WAFSA_GB2_WIDX $job $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2.idx
   fi

   if [ $SENDDBN_NTC = "YES" -a $SEND_US_WAFS = "YES" ] ; then
      $DBNROOT/bin/dbn_alert NTC_LOW $NET $job $PCOM/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr}.grib2
   fi
   export SEND_US_WAFS=NO
   exit
fi

##############################################################################################
 #
 # TOCGRIB2 Processing WAFS Blending GRIB2 (Icing, CB, GTG)
. prep_step
startmsg

export FORT11=0p25_blended_${PDY}${cyc}f${ffhr}.grib2
export FORT31=" "
export FORT51=grib2.t${cyc}z.WAFS_0p25_blended_f${ffhr}

$TOCGRIB2 <  $FIXgfs/grib2_blended_wafs_wifs_f${ffhr}.0p25 >> $pgmout 2> errfile

err=$?;export err ;err_chk
echo " error from tocgrib=",$err

##############################################################################################
 #
 #   Distribute US WAFS unblend Data to NCEP FTP Server (WOC) and TOC
 #
if [ $SENDCOM = YES ]; then
   cp 0p25_blended_${PDY}${cyc}f${ffhr}.grib2 $COMOUT/WAFS_0p25_blended_${PDY}${cyc}f${ffhr}.grib2
   cp grib2.t${cyc}z.WAFS_0p25_blended_f${ffhr}  $PCOM/grib2.t${cyc}z.WAFS_0p25_blended_f${ffhr}
fi

if [ $SENDDBN_NTC = "YES" ] ; then
#   Distribute Data to NCEP FTP Server (WOC) and TOC
    $DBNROOT/bin/dbn_alert NTC_LOW $NET $job $PCOM/grib2.t${cyc}z.WAFS_0p25_blended_f${ffhr}
fi

if [ $SENDDBN = "YES" ] ; then
    $DBNROOT/bin/dbn_alert MODEL GFS_WAFSA_BL_GB2 $job $COMOUT/WAFS_0p25_blended_${PDY}${cyc}f${ffhr}.grib2
fi 

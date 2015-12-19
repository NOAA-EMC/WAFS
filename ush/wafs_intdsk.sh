#!/bin/sh
#
#  UTILITY SCRIPT NAME :  wafs_intdsk.sh
#               AUTHOR :  Boi Vuong 
#         DATE WRITTEN :  06/12/2000
#
#  Abstract:  This utility script produces the GFS WAFS  
#             for grib grids i37,38,39,40,41,42,43 and 44
#             for international desk. These grid files
#             send to TOC.
#
#     Input:  1 argument is passed to this script.
#             1st argument - Forecast Hour (00 to 120)
#
echo "History: June  2000 - First implementation of this utility script"
echo "         Aug 2015 - Modified for Phase II"
echo " "
#

set +x
fcsthrs_list="$1"
num=$#

if test $num -ne 1
then
   echo ""
   echo "   Usage: wafs_intdsk.sh  forecast_hour"
   echo ""
   echo "   Example:"
   echo '           wafs_intdsk.sh  "00 06 12 18 24" '
   echo ""
   echo ""
   exit 16
fi

set -x

cd $DATA

#####################################
# Define Script/Exec and Variables
#####################################

#export cyc=${cyc:-00}
#export cycle=${cycle:-t${cyc}z}
#export jlogfile=${jlogfile:-jlogfile}
#export envir=${envir:-prod}

#export GRBIDX=/nwprod/util/exec/grbindex
#export WGRIB2=/nwprod/util/exec/wgrib2
#export CNVGRIB=/nwprod/util/exec/cnvgrib
#export EXECutil=${EXECutil:-/nwprod/util/exec}
#export PARMutil=${PARMutil:-/nwprod/util/parm}
#export SENDCOM=${SENDCOM:-NO}
#export SENDDBN=${SENDDBN:-NO}
#export RUN=${RUN:-gfs}
#export NET=${NET:-gfs}
#export COMIN=${COMIN:-/com/$NET/$envir/$NET.$PDY}

echo " ------------------------------------------"
echo " BEGIN MAKING ${NET} WAFS PRODUCTS"
echo " ------------------------------------------"

msg="Enter Make WAFS utility."
postmsg "$jlogfile" "$msg"
echo " "

for hour in $fcsthrs_list 
do 
   if test ! -f pgrbf${hour}
   then
#      cpfs $COMIN/${RUN}.${cycle}.pgrbf${hour} pgrbf${hour}
#      file name and forecast hour of GFS model data in Grib2 are 3 digits
      hour000="$(printf "%03d" $hour)"
      $CNVGRIB -g21 $COMIN/${RUN}.${cycle}.pgrb2.1p00.f$hour000 pgrbf${hour}
   fi

   for gid in 37 38 39 40 41 42 43 44;
   do
      $WGRIB pgrbf${hour} | grep -F -f $parmlist | $WGRIB -i -grib -o tmpfile pgrbf${hour}
      $COPYGB -g${gid} -i0 -x tmpfile wafs${NET}${gid}.t${cyc}z.gribf${hour}
     
      ##########################
      # Convert to grib2 format
      ##########################
      $CNVGRIB -g12 -p40 wafs${NET}${gid}.t${cyc}z.gribf${hour} wafs${NET}${gid}.t${cyc}z.gribf${hour}.grib2
      $WGRIB2 wafs${NET}${gid}.t${cyc}z.gribf${hour}.grib2 -s >wafs${NET}${gid}.t${cyc}z.gribf${hour}.grib2.idx
 
      cpfs wafs${NET}${gid}.t${cyc}z.gribf${hour}   $COMOUT
      cpfs wafs${NET}${gid}.t${cyc}z.gribf${hour}.grib2 $COMOUT
      cpfs wafs${NET}${gid}.t${cyc}z.gribf${hour}.grib2.idx $COMOUT

      chmod 775 $COMOUT/wafs${NET}${gid}.t${cyc}z.gribf${hour}
      if [ "$SENDDBN" = "YES" ]
      then
         $DBNROOT/bin/dbn_alert MODEL GFS_WAFS_INT $job $COMOUT/wafs${NET}${gid}.t${cyc}z.gribf${hour}
         $DBNROOT/bin/dbn_alert MODEL GFS_WAFSG  $job $COMOUT/wafs${NET}${gid}.t${cyc}z.gribf${hour}

         if [ $SENDDBN_GB2 = YES ]
         then

         $DBNROOT/bin/dbn_alert MODEL GFS_WAFSG_GB2 $job $COMOUT/wafs${NET}${gid}.t${cyc}z.gribf${hour}.grib2
         $DBNROOT/bin/dbn_alert MODEL GFS_WAFSG_GB2_WIDX $job $COMOUT/wafs${NET}${gid}.t${cyc}z.gribf${hour}.grib2.idx

         fi

      fi
   done
   rm tmpfile pgrbf${hour}
done

msg="wafs_intdsk completed normally"
postmsg "$jlogfile" "$msg"

exit

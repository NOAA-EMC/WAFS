#  UTILITY SCRIPT NAME :  mkwfsgbl.sh
#               AUTHOR :  Mary Jacobs
#         DATE WRITTEN :  11/06/96
#
#  Abstract:  This utility script produces the GFS WAFS
#             bulletins.  
#
#     Input:  2 arguments are passed to this script.   
#             1st argument - Forecast Hour - format of 2I
#             2nd argument - In hours 12-30, the designator of 
#                            a  or  b.
#
#     Logic:   If we are processing hours 12-30, we have the
#              added variable of the   a   or    b, and process
#              accordingly.  The other hours, the a or b  is dropped.
#
echo "History: SEPT    1996 - First implementation of this utility script"
echo "History: AUG     1999 - Modified for implementation on IBM SP"
echo "                      - Allows users to run interactively" 
#

set -x
hour_list="$1"
sets_key=$2
num=$#

if test $num -ge 2
then
   echo " Appropriate number of arguments were passed"
   set -x
   export EXECutil=${EXECutil:-/nwprod/util/exec} 
   export PARMutil=${PARMutil:-/nwprod/util/parm} 
   export envir=${envir:-prod} 
   export jlogfile=${jlogfile:-jlogfile} 
   export NET=${NET:-gfs} 
   export RUN=${RUN:-gfs} 
   export cyc=${cyc:-00} 
   export cycle=${cycle:-t${cyc}z} 
   export SENDCOM=${SENDCOM:-NO}
   export SENDDBN=${SENDDBN:-NO}
   if [ -z "$DATA" ]
   then
      export DATA=`pwd`
      cd $DATA
      /nwprod/util/ush/setup.sh
      /nwprod/util/ush/setpdy.sh
      . PDY
   fi
   export COMIN=${COMIN:-/com/$NET/$envir/$NET.$PDY} 
   export pcom=${pcom:-/pcom/$NET} 
   export job=${job:-interactive} 
   export pgmout=${pgmout:-OUTPUT.$$}
else
   echo ""
   echo "Usage: mkwfsgbl.sh \$hour [a|b]"
   echo ""
   exit 16
fi

echo " ------------------------------------------"
echo " BEGIN MAKING ${NET} WAFS PRODUCTS"
echo " ------------------------------------------"

msg="Enter Make WAFS utility."
postmsg "$jlogfile" "$msg"

for hour in $hour_list
do
   ##############################
   # Copy Input Field to $DATA
   ##############################

   if test ! -f pgrbf${hour}
   then
      cp $COMIN/${RUN}.${cycle}.pgrbf${hour} pgrbf${hour}
   fi

   #
   # BAG - Put in fix on 20070925 to force the percision of U and V winds
   #       to default to 1 through the use of the wafs.namelist file.
   #
   $EXECutil/copygb -g3 -i0 -N$PARMgfs/wafs.namelist -x pgrbf${hour} tmp
   mv tmp pgrbf${hour}
   $EXECutil/grbindex pgrbf${hour} pgrbif${hour}

   ##############################
   # Process WAFS
   ##############################

   if test $hour -ge '12' -a $hour -le '30'
   then
       sets=$sets_key
       set +x
       echo "We are processing the primary and secondary sets of hours."
       echo "These sets are the   a   and   b   of hours 12-30."
       set -x
   else
     # This is for hours 00/06 and 36-72.
     unset sets
   fi

   export pgm=makewafs
   . prep_step

   export FORT11="pgrbf${hour}"
   export FORT31="pgrbif${hour}"
   export FORT51="xtrn.wfs${NET}${hour}${sets}"
   export FORT53="com.wafs${hour}${sets}"

   startmsg
   $EXECutil/makewafs < $PARMgfs/grib_wfs${NET}${hour}${sets} >>$pgmout 2>errfile
   export err=$?;err_chk


   ##############################
   # Post Files to PCOM 
   ##############################

   if test "$SENDCOM" = 'YES'
   then
      cp xtrn.wfs${NET}${hour}${sets} $pcom/xtrn.wfs${NET}${cyc}${hour}${sets}.$job
      cp com.wafs${hour}${sets} $pcom/com.wafs${cyc}${hour}${sets}.$job

      if test "$SENDDBN_NTC" = 'YES'
      then
         if test "$NET" = 'gfs'
         then
               $DBNROOT/bin/dbn_alert MODEL GFS_WAFS $job \
                         $pcom/com.wafs${cyc}${hour}${sets}.$job
               $DBNROOT/bin/dbn_alert MODEL GFS_XWAFS $job \
                         $pcom/xtrn.wfs${NET}${cyc}${hour}${sets}.$job
         fi
      fi
   fi

   ##############################
   # Distribute Data 
   ##############################

   if [ "$SENDDBN_NTC" = 'YES' ] ; then
      $DBNROOT/bin/dbn_alert GRIB_LOW $NET $job $pcom/xtrn.wfs${NET}${cyc}${hour}${sets}.$job
   else
      msg="xtrn.wfs${NET}${cyc}${hour}${sets}.$job file not posted to db_net."
      postmsg "$jlogfile" "$msg"
   fi

   msg="Wafs Processing $hour hour completed normally"
   postmsg "$jlogfile" "$msg"

done

exit

#!/bin/bash

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
fhr="$1"
sets_key=$2
num=$#

if test $num -ge 2
then
   echo " Appropriate number of arguments were passed"
   set -x
   if [ -z "$DATA" ]
   then
      export DATA=`pwd`
      cd $DATA
      setpdy.sh
      . PDY
   fi
else
   echo ""
   echo "Usage: mkwfsgbl.sh \$hour [a|b]"
   echo ""
   exit 16
fi

echo " ------------------------------------------"
echo " BEGIN MAKING gfs WAFS PRODUCTS"
echo " ------------------------------------------"

echo "Enter Make WAFS utility."

##############################
# Copy Input Field to $DATA
##############################

if test ! -f pgrbf${fhr}
then
    fhr3="$(printf "%03d" $(( 10#$fhr )) )"

#      To solve Bugzilla #408: remove the dependency of grib1 files in gfs wafs job in next GFS upgrade
#      Reason: It's not efficent if simply converting from grib2 to grib1 (costs 6 seconds with 415 records)
#      Solution: Need to grep 'selected fields on selected levels' before CNVGRIB (costs 1 second with 92 records)
#       ln -s $COMINgfs/gfs.${cycle}.pgrb2.1p00.f$fhr3  pgrb2f${fhr}
#       $WGRIB2 pgrb2f${fhr} | grep -F -f $FIXwafs/grib_wafs.grb2to1.list | $WGRIB2 -i pgrb2f${fhr} -grib pgrb2f${fhr}.tmp
    masterfile=$COMINgfs/gfs.${cycle}.master.grb2f${fhr3}
    $WGRIB2 $masterfile | grep -F -f $FIXwafs/grib_wafs.grb2to1.list | $WGRIB2 -i $masterfile -grib masterf$fhr
       
    # Change data input from 1p00 files to master files
    export opt1=' -set_grib_type same -new_grid_winds earth '
    export opt21=' -new_grid_interpolation bilinear '
    export opt24=' -set_bitmap 1 -set_grib_max_bits 16 -if '
    export opt25=":(APCP|ACPCP):"
    export opt26=' -set_grib_max_bits 25 -fi -if '
    export opt27=":(APCP|ACPCP):"
    export opt28=' -new_grid_interpolation budget -fi '
    export grid1p0="latlon 0:360:1.0 90:181:-1.0"
    $WGRIB2 masterf$fhr $opt1 $opt21 $opt24 $opt25 $opt26 $opt27 $opt28 \
            -new_grid $grid1p0  pgb2file_${fhr}1p00

    # trim RH vaule larger than 100.
    $WGRIB2 pgb2file_${fhr}1p00 -not_if ':RH:' -grib pgrb2f${fhr}.tmp \
            -if ':RH:' -rpn "10:*:0.5:+:floor:1000:min:10:/" -set_grib_type same \
            -set_scaling -1 0 -grib_out pgrb2f${fhr}.tmp
       
    $CNVGRIB -g21 pgrb2f${fhr}.tmp  pgrbf${fhr}
fi

#
# BAG - Put in fix on 20070925 to force the percision of U and V winds
#       to default to 1 through the use of the grib_wafs.namelist file.
#
$COPYGB -g3 -i0 -N$FIXwafs/grib_wafs.namelist -x pgrbf${fhr} tmp
mv tmp pgrbf${fhr}
$GRBINDEX pgrbf${fhr} pgrbif${fhr}

##############################
# Process WAFS
##############################

if test $fhr -ge '12' -a $fhr -le '30'
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

export pgm=wafs_makewafs
. prep_step

export FORT11="pgrbf${fhr}"
export FORT31="pgrbif${fhr}"
export FORT51="xtrn.wfsgfs${fhr}${sets}"
export FORT53="com.wafs${fhr}${sets}"

startmsg
$EXECwafs/wafs_makewafs.x < $FIXwafs/grib_wfsgfs${fhr}${sets} >>$pgmout 2>errfile
export err=$?;err_chk


##############################
# Post Files to PCOM 
##############################

if test "$SENDCOM" = 'YES'
then
    cpfs xtrn.wfsgfs${fhr}${sets} $PCOM/xtrn.wfsgfs${cyc}${fhr}${sets}.$jobsuffix
fi

##############################
# Distribute Data 
##############################

if [ "$SENDDBN_NTC" = 'YES' ] ; then
    $DBNROOT/bin/dbn_alert GRIB_LOW gfs $job $PCOM/xtrn.wfsgfs${cyc}${fhr}${sets}.$jobsuffix
else
    echo "xtrn.wfsgfs${cyc}${fhr}${sets}.$job file not posted to db_net."
fi

echo "Wafs Processing $fhr hour completed normally"

exit

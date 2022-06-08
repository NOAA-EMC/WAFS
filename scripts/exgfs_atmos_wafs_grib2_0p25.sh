#!/bin/sh
######################################################################
#  UTILITY SCRIPT NAME :  exgfs_atmos_wafs_grib2_0p25.sh
#         DATE WRITTEN :  03/20/2020
#
#  Abstract:  This utility script produces the WAFS GRIB2 at 0.25 degree.
#             The output GRIB files are posted on NCEP ftp server and the
#             grib2 files are pushed via dbnet to TOC to WAFS (ICSC).  
#             This is a joint project of WAFC London and WAFC Washington.
#
#             We are processing WAFS grib2 for ffhr:
#             hourly: 006 - 024
#             3 hour: 027 - 048
#             6 hour: 054 - 120 (for U/V/T/RH, not for turbulence/icing/CB)
#
# History:  
#####################################################################
echo "-----------------------------------------------------"
echo "JGFS_ATMOS_WAFS_GRIB2_0P25 at 00Z/06Z/12Z/18Z GFS postprocessing"
echo "-----------------------------------------------------"
echo "History: MARCH  2020 - First implementation of this new script."
echo "Oct 2021 - Remove jlogfile"
echo "Aug 2022 - ffhr expanded from 36 to 120"
echo " "
#####################################################################

cd $DATA

set -x


ffhr=$1
export ffhr="$(printf "%03d" $(( 10#$ffhr )) )"
export ffhr2="$(printf "%02d" $(( 10#$ffhr )) )"

DATA=$DATA/$ffhr
mkdir -p $DATA
cd $DATA


if [ $ffhr -le 48 ] ; then
    hazard_timewindow=yes
else
    hazard_timewindow=no
fi


##########################################################
# Wait for the availability of the gfs WAFS file
##########################################################

# 3D data (on new ICAO model pressure levels) and 2D data (CB)
wafs2=$COMIN/${RUN}.${cycle}.wafs.grb2f${ffhr}
wafs2i=$COMIN/${RUN}.${cycle}.wafs.grb2f${ffhr}.idx

# 2D data from master file (U/V/H on max wind level, T/H at tropopause)
master2=$COMIN/${RUN}.${cycle}.master.grb2f${ffhr}

# 3D data (on standard atmospheric pressure levels)
# Up to fhour=48
# Will be removed in GFS.v17
icao2=$COMIN/${RUN}.${cycle}.wafs_icao.grb2f${ffhr}
  
icnt=1
while [ $icnt -lt 1000 ]
do
    if [[ -s $wafs2i ]] ; then
      break
    fi

    sleep 10
    icnt=$((icnt + 1))
    if [ $icnt -ge 180 ] ;    then
        msg="ABORTING after 30 min of waiting for the gfs wafs file!"
        err_exit $msg
    fi
done


########################################
echo "HAS BEGUN!"
########################################

echo " ------------------------------------------"
echo " BEGIN MAKING GFS WAFS GRIB2 0.25 DEG PRODUCTS"
echo " ------------------------------------------"

set +x
echo " "
echo "#####################################"
echo "      Process GRIB2 WAFS 0.25 DEG PRODUCTS     "
echo "#####################################"
echo " "
set -x

opt1=' -set_grib_type same -new_grid_winds earth '
opt21=' -new_grid_interpolation bilinear  -if '
opt22="(:ICESEV|parm=37):"
opt23=' -new_grid_interpolation neighbor -fi '
opt24=' -set_bitmap 1 -set_grib_max_bits 16 '
opt25=":(UGRD|VGRD):max wind"
newgrid="latlon 0:1440:0.25 90:721:-0.25"

# WAFS 3D data
$WGRIB2 $wafs2 $opt1 $opt21 $opt22 $opt23 $opt24 -new_grid $newgrid tmp_wafs_0p25.grb2
# Master 2D data
$WGRIB2 $master2 | grep -F -f $FIXgfs/gfs_master.grb2_0p25.list \
    | $WGRIB2 -i $master2 -set master_table 25 -grib tmp_master.grb2
$WGRIB2 tmp_master.grb2 $opt1 $opt21 ":(UGRD|VGRD):max wind" $opt23 $opt24 -new_grid $newgrid tmp_master_0p25.grb2

#---------------------------
# Product 1: WAFS u/v/t/rh gfs.tHHz.wafs_0p25.fFFF.grib2
#---------------------------
$WGRIB2 tmp_wafs_0p25.grb2 | egrep "UGRD|VGRD|TMP|HGT|RH" \
    | $WGRIB2 -i tmp_wafs_0p25.grb2 -set master_table 25 -grib tmp.gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2
cat tmp_master_0p25.grb2 >> tmp.gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2
# Convert template 5 to 5.40
$WGRIB2 tmp.gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2 -set_grib_type jpeg -grib_out gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2
$WGRIB2 -s gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2 > gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2.idx

if [ "$ICAO2023" = 'yes' ] ; then
    if [ $hazard_timewindow = 'yes' ] ; then
#---------------------------
# Product 2: For AWC and Delta airline: EDPARM CAT MWT ICESEV (no CB)  gfs.tHHz.awf_0p25.fFFF.grib2
#---------------------------
	criteria1=":EDPARM:|:ICESEV:|parm=37:"
	criteria2=":CATEDR:|:MWTURB:"
	$WGRIB2 tmp_wafs_0p25.grb2 | egrep "${criteria1}|$criteria2" \
	    | $WGRIB2 -i tmp_wafs_0p25.grb2 -grib gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2
	$WGRIB2 -s gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2 > gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2.idx

	#$WGRIB2 $icao2 $opt1 $opt21 $opt22 $opt23 $opt24 -new_grid $newgrid tmp_icao_0p25.grb2      
	# For AWC and Delta airline: new ICAO levels, including EDPARM, CAT, WMT and ICESEV (No CB)
	#$WGRIB2 tmp_0p25.grb2 | grep -F -f $FIXgfs/wafs_gfsmaster_delta.grb2_0p25.list \
	    #  | $WGRIB2 -i tmp_0p25.grb2 -grib gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2
#---------------------------
# Product 3: WAFS unblended EDPARM, ICESEV, CB (No CAT MWT) gfs.tHHz.wafs_0p25_unblended.fFF.grib2
#---------------------------
	$WGRIB2 tmp_wafs_0p25.grb2 | grep -F -f $FIXgfs/gfs_wafs.grb2_0p25.list \
	    | $WGRIB2 -i tmp_wafs_0p25.grb2 -set master_table 25 -grib tmp_wafs_0p25.grb2.forblend

	# Convert template 5 to 5.40
	$WGRIB2 tmp_wafs_0p25.grb2.forblend -set_grib_type jpeg -grib_out gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2
	$WGRIB2 -s gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2 > gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2.idx
    fi

else # icao2 on standard atmosphere pressure levels, relabeled to ICAO pressure levels every 25mb
#---------------------------
# Product 2 (before 2023): For AWC and Delta airline: EDPARM CAT MWT ICESEV (no CB)  gfs.tHHz.awf_0p25.fFFF.grib2
#---------------------------
    criteria1=":EDPARM:|:ICESEV:|parm=37:"
    criteria2=":CATEDR:|:MWTURB:"
    $WGRIB2 $icao2 | egrep "${criteria1}|$criteria2" | egrep -v ":70 mb:" | $WGRIB2 -i $icao2 -grib tmp_icao2_grb2
    $WGRIB2 tmp_icao2_grb2 $opt1 $opt21 $opt22 $opt23 $opt24 -new_grid $newgrid gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2
    $WGRIB2 -s gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2 > gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2.idx

#---------------------------
# Product 3 (before 2023): WAFS unblended EDPARM, ICESEV, CB (No CAT MWT) gfs.tHHz.wafs_0p25_unblended.fFF.grib2
#---------------------------
    $WGRIB2 gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2 | egrep -v $criteria2 \
	| $WGRIB2 -i gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2 -grib tmp_awf_grb2.0p25.forblend

    # Collect CB fields, convert to 1/4 deg
    criteria=":CBHE:|:ICAHT:"
    $WGRIB2 $wafs2 | egrep $criteria | $WGRIB2 -i $wafs2 -grib tmp_wafs2_grb2
    $WGRIB2 tmp_wafs2_grb2 $opt1 $opt21 $opt22 $opt23 $opt24 -new_grid $newgrid tmp_wafs_grb2.0p25

    cat tmp_awf_grb2.0p25.forblend >> tmp_wafs_grb2.0p25

    # Relabel pressure levels to exact numbers and change to grib2 template 5.40
    # (Relabelling should be removed when UPP WAFS output on the exact pressure levels)
    export pgm=wafs_grib2_0p25
    . prep_step
    startmsg
    $EXECgfs/$pgm tmp_wafs_grb2.0p25 tmp_0p25_exact.grb2 >> $pgmout 2> errfile
    export err=$?; err_chk
# WGRIB2 set_lev doesn't work well. The output will fail on DEGRIB2 and
# it change values of octet 30, octet 31-34 of template 4 from 0 to undefined values
#  $WGRIB2 tmp_0p25_ref.grb2 \
#      -if ":100 mb" -set_lev "100.4 mb" -fi \
#      -if ":125 mb" -set_lev "127.7 mb" -fi \
#      -if ":150 mb" -set_lev "147.5 mb" -fi \
#      -if ":175 mb" -set_lev "178.7 mb" -fi \
#      -if ":200 mb" -set_lev "196.8 mb" -fi \
#      -if ":225 mb" -set_lev "227.3 mb" -fi \
#      -if ":275 mb" -set_lev "274.5 mb" -fi \
#      -if ":300 mb" -set_lev "300.9 mb" -fi \
#      -if ":350 mb" -set_lev "344.3 mb" -fi \
#      -if ":400 mb" -set_lev "392.7 mb" -fi \
#      -if ":450 mb" -set_lev "446.5 mb" -fi \
#      -if ":500 mb" -set_lev "506 mb" -fi \
#      -if ":600 mb" -set_lev "595.2 mb" -fi \
#      -if ":700 mb" -set_lev "696.8 mb" -fi \
#      -if ":750 mb" -set_lev "752.6 mb" -fi \
#      -if ":800 mb" -set_lev "812 mb" -fi \
#      -if ":850 mb" -set_lev "843.1 mb" -fi \
#      -grib tmp_0p25_exact.grb2

    # Filter limited levels according to ICAO standard
    $WGRIB2 tmp_0p25_exact.grb2 | grep -F -f $FIXgfs/legend/wafs_gfsmaster.grb2_0p25.list \
        | $WGRIB2 -i tmp_0p25_exact.grb2 -set master_table 25 -grib gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2
    $WGRIB2 -s gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2 > gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2.idx  
fi

###### Step 6 TOCGIB2 ######
# As in August 2020, no WMO header is needed for WAFS data at 1/4 deg
## . prep_step
## startmsg
## export FORT11=gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2
## export FORT31=" "
## export FORT51=gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr2}.grib2
## $TOCGRIB2 <  $FIXgfs/grib2_gfs_wafs_wifs_f${ffhr}.0p25 >> $pgmout 2> errfile
## err=$?;export err ;err_chk
## echo " error from tocgrib2=",$err

if [ $SENDCOM = "YES" ] ; then

   ##############################
   # Post Files to COM
   ##############################

    mv gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2 $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2
    mv gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2.idx $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2.idx

   if [ $hazard_timewindow = 'yes' ] ; then
       mv gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2 $COMOUT/gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2
       mv gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2.idx $COMOUT/gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2.idx
       
       mv gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2 $COMOUT/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2
       mv gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2.idx $COMOUT/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2.idx
   fi

   #############################
   # Post Files to PCOM
   ##############################
   ## mv gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr2}.grib2 $PCOM/gfs.t${cyc}z.wafs_0p25_unblended_wifs.f${ffhr2}.grib2
fi


if [ $SENDDBN = "YES" ] ; then
   ######################
   # Distribute Data
   ######################

    # Hazard WAFS data (ICESEV EDR CAT MWT on 100mb to 1000mb or on new ICAO 2023 levels) sent to AWC and to NOMADS for US stakeholders
#    $DBNROOT/bin/dbn_alert MODEL GFS_WAFS_0P25_GB2 $job $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2
    $DBNROOT/bin/dbn_alert MODEL GFS_AWF_0P25_GB2 $job $COMOUT/gfs.t${cyc}z.awf_0p25.f${ffhr}.grib2

    # Unblended US WAFS data sent to UK for blending, to the same server as 1.25 deg unblended data: wmo/grib2.tCCz.wafs_grb_wifsfFF.45
    $DBNROOT/bin/dbn_alert MODEL GFS_WAFS_0P25_UBL_GB2 $job $COMOUT/gfs.t${cyc}z.wafs_0p25_unblended.f${ffhr2}.grib2
    # WAFS U/V/T/RH data sent to the same server as the unblended data as above
    $DBNROOT/bin/dbn_alert MODEL GFS_WAFS_0P25_GB2 $job $COMOUT/gfs.t${cyc}z.wafs_0p25.f${ffhr}.grib2

fi

################################################################################
# GOOD RUN
set +x
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
set -x
################################################################################

echo "HAS COMPLETED NORMALLY!"

exit 0

############## END OF SCRIPT #######################

#!/bin/bash

######################################################################
#  UTILITY SCRIPT NAME :  exwafs_grib2_0p25.sh
#         DATE WRITTEN :  03/20/2020
#
#  Abstract:  This utility script produces the WAFS GRIB2 at 0.25 degree.
#             The output GRIB files are posted on NCEP ftp server and the
#             grib2 files are pushed via dbnet to TOC to WAFS (ICSC).  
#             This is a joint project of WAFC London and WAFC Washington.
#
#             We are processing WAFS grib2 for fhr:
#             hourly: 006 - 024
#             3 hour: 027 - 048
#             6 hour: 054 - 120 (for U/V/T/RH, not for turbulence/icing/CB)
#
# History:  
#####################################################################
echo "-----------------------------------------------------"
echo "JWAFS_GRIB2_0P25 at 00Z/06Z/12Z/18Z GFS&WAFS postprocessing"
echo "-----------------------------------------------------"
echo "History: MARCH  2020 - First implementation of this new script."
echo "Oct 2021 - Remove jlogfile"
echo "Aug 2022 - fhr expanded from 36 to 120"
echo "May 2024 - WAFS separation"
echo " "
#####################################################################

cd $DATA

set -x


fhr=$1
export fhr="$(printf "%03d" $(( 10#$fhr )) )"

DATA=$DATA/$fhr
mkdir -p $DATA
cd $DATA


if [ $fhr -le 48 ] ; then
    hazard_timewindow=yes
else
    hazard_timewindow=no
fi


##########################################################
# Wait for the availability of the gfs WAFS file
##########################################################

# 3D data (on new ICAO model pressure levels) and 2D data (CB)
wafs2=$COMIN/${RUN}.${cycle}.master.f$fhr.grib2
wafs2i=$COMIN/${RUN}.${cycle}.master.f$fhr.grib2.idx

# 2D data from master file (U/V/H on max wind level, T/H at tropopause)
master2=$COMINgfs/gfs.${cycle}.master.grb2f${fhr}
master2i=$COMINgfs/gfs.${cycle}.master.grb2if${fhr}

########################################
echo "HAS BEGUN!"
########################################

echo " ------------------------------------------"
echo " BEGIN MAKING WAFS GRIB2 0.25 DEG PRODUCTS"
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
$WGRIB2 $master2 | grep -F -f $FIXwafs/grib2_0p25_gfs_master2d.list \
    | $WGRIB2 -i $master2 -set master_table 25 -grib tmp_master.grb2
$WGRIB2 tmp_master.grb2 $opt1 $opt21 ":(UGRD|VGRD):max wind" $opt23 $opt24 -new_grid $newgrid tmp_master_0p25.grb2

#---------------------------
# Product 1: WAFS u/v/t/rh wafs.tHHz.0p25.fFFF.grib2
#---------------------------
$WGRIB2 tmp_wafs_0p25.grb2 | egrep "UGRD|VGRD|TMP|HGT|RH" \
    | $WGRIB2 -i tmp_wafs_0p25.grb2 -set master_table 25 -grib tmp.${RUN}.t${cyc}z.0p25.f${fhr}.grib2
cat tmp_master_0p25.grb2 >> tmp.${RUN}.t${cyc}z.0p25.f${fhr}.grib2
# Convert template 5 to 5.40
#$WGRIB2 tmp.${RUN}.t${cyc}z.0p25.f${fhr}.grib2 -set_grib_type jpeg -grib_out ${RUN}.t${cyc}z.0p25.f${fhr}.grib2
mv tmp.${RUN}.t${cyc}z.0p25.f${fhr}.grib2 ${RUN}.t${cyc}z.0p25.f${fhr}.grib2
$WGRIB2 -s ${RUN}.t${cyc}z.0p25.f${fhr}.grib2 > ${RUN}.t${cyc}z.0p25.f${fhr}.grib2.idx

if [ $hazard_timewindow = 'yes' ] ; then
#---------------------------
# Product 2: For AWC and Delta airline: EDPARM CAT MWT ICESEV CB  wafs.tHHz.awf.0p25.fFFF.grib2
#---------------------------
    criteria1=":EDPARM:|:ICESEV:|parm=37:"
    criteria2=":CATEDR:|:MWTURB:"
    criteria3=":CBHE:|:ICAHT:"
    $WGRIB2 tmp_wafs_0p25.grb2 | egrep "${criteria1}|$criteria2|$criteria3" \
	| $WGRIB2 -i tmp_wafs_0p25.grb2 -grib ${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2
    $WGRIB2 -s ${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2 > ${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2.idx

#---------------------------
# Product 3: WAFS unblended EDPARM, ICESEV, CB (No CAT MWT) wafs.tHHz.unblended.0p25.fFFF.grib2
#---------------------------
    $WGRIB2 tmp_wafs_0p25.grb2 | grep -F -f $FIXwafs/grib2_0p25_wafs_hazard.list \
	| $WGRIB2 -i tmp_wafs_0p25.grb2 -set master_table 25 -grib tmp_wafs_0p25.grb2.forblend

    # Convert template 5 to 5.40
    #$WGRIB2 tmp_wafs_0p25.grb2.forblend -set_grib_type jpeg -grib_out ${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2
    mv tmp_wafs_0p25.grb2.forblend ${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2
    $WGRIB2 -s ${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2 > ${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2.idx
fi

if [ $SENDCOM = "YES" ] ; then

   ##############################
   # Post Files to COM
   ##############################

    cpfs ${RUN}.t${cyc}z.0p25.f${fhr}.grib2 $COMOUT/${RUN}.t${cyc}z.0p25.f${fhr}.grib2
    mv ${RUN}.t${cyc}z.0p25.f${fhr}.grib2.idx $COMOUT/${RUN}.t${cyc}z.0p25.f${fhr}.grib2.idx

   if [ $hazard_timewindow = 'yes' ] ; then
       mv ${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2 $COMOUT/${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2
       mv ${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2.idx $COMOUT/${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2.idx
       
       mv ${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2 $COMOUT/${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2
       mv ${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2.idx $COMOUT/${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2.idx
   fi

fi

if [ $SENDDBN = "YES" ] ; then
   ######################
   # Distribute Data
   ######################

    if [ $hazard_timewindow = 'yes' ] ; then
	# Hazard WAFS data (ICESEV EDR CAT MWT on 100mb to 1000mb or on new ICAO levels) sent to AWC and to NOMADS for US stakeholders
	$DBNROOT/bin/dbn_alert MODEL WAFS_AWF.0P25_GB2 $job $COMOUT/${RUN}.t${cyc}z.awf.0p25.f${fhr}.grib2

	# Unblended US WAFS data sent to UK for blending, to the same server as 1.25 deg unblended data: wmo/grib2.tCCz.wafs_grb_wifsfFF.45
	$DBNROOT/bin/dbn_alert MODEL WAFS_0P25_UBL_GB2 $job $COMOUT/${RUN}.t${cyc}z.unblended.0p25.f${fhr}.grib2
    fi

    # WAFS U/V/T/RH data sent to the same server as the unblended data as above
    $DBNROOT/bin/dbn_alert MODEL WAFS_0P25_GB2 $job $COMOUT/${RUN}.t${cyc}z.0p25.f${fhr}.grib2

fi

################################################################################
# GOOD RUN
set +x
echo "**************JOB EXWAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXWAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXWAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
set -x
################################################################################

echo "HAS COMPLETED NORMALLY!"

exit 0

############## END OF SCRIPT #######################

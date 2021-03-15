#!/bin/sh
######################################################################
#  UTILITY SCRIPT NAME :  exgfs_atmos_wafs_gtg_makeup.sh
#         DATE WRITTEN :  03/14/2021
#
#  Abstract:  This utility script produces the WAFS GRIB2 at 0.25 degree.
#             Make up CAT and MWT two fields output
#
#             We are processing WAFS grib2 for ffhr from 06 - 36 
#             with 3-hour time increment.
#
# History:  
#####################################################################
echo "-----------------------------------------------------"
echo "JGFS_ATMOS_WAFS_GTG_MAKEUP at 00Z/06Z/12Z/18Z GFS postprocessing"
echo "-----------------------------------------------------"
echo "History: MARCH  2021 - First implementation of this new script."
echo " "
#####################################################################

cd $DATA

set -x

export SLEEP_LOOP_MAX=`expr $SLEEP_TIME / $SLEEP_INT`
export ffhr=$SHOUR
while test $ffhr -le $EHOUR
do
  export ffhr="$(printf "%02d" $(( 10#$ffhr )) )"
  # file name and forecast hour of GFS model data in Grib2 are 3 digits
  export ffhr000="$(printf "%03d" $(( 10#$ffhr )) )"
##########################################################
# Wait for the availability of the gfs WAFS file
##########################################################

  # 3D data (Icing, Turbulence) and 2D data (CB)
  wafs2=$COMIN/${RUN}.${cycle}.wafs.grb2f${ffhr000}
  wafs2i=$COMIN/${RUN}.${cycle}.wafs.grb2if${ffhr000}

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
  msg="HAS BEGUN!"
  postmsg "$jlogfile" "$msg"
  ########################################

  echo " ------------------------------------------"
  echo " BEGIN MAKING UP GFS WAFS GRIB2 0.25 DEG PRODUCTS"
  echo " ------------------------------------------"

  set +x
  echo " "
  echo "#####################################"
  echo "      Process GRIB2 WAFS 0.25 DEG PRODUCTS     "
  echo "#####################################"
  echo " "
  set -x

  opt1=' -set_grib_type same -new_grid_winds earth '
  opt2=' -new_grid_interpolation bilinear '
  opt3=' -set_bitmap 1 -set_grib_max_bits 16 '
  newgrid="latlon 0:1440:0.25 90:721:-0.25"

  criteria=":CATEDR:|:MWTURB:"
  $WGRIB2 $wafs2 | egrep $criteria | egrep -v ":70 mb:" | $WGRIB2 -i $wafs2 -grib tmp_wafs2_grb2
  $WGRIB2 tmp_wafs2_grb2 $opt1 $opt2 $opt3 -new_grid $newgrid gfs.t${cyc}z.wafs2_0p25.f${ffhr}.grib2
  $WGRIB2 -s gfs.t${cyc}z.wafs2_0p25.f${ffhr}.grib2 > gfs.t${cyc}z.wafs2_0p25.f${ffhr}.grib2.idx

  if [ $SENDCOM = "YES" ] ; then

   ##############################
   # Post Files to COM
   ##############################

     mv gfs.t${cyc}z.wafs2_0p25.f${ffhr}.grib2 $COMOUT/gfs.t${cyc}z.wafs2_0p25.f${ffhr000}.grib2
     mv gfs.t${cyc}z.wafs2_0p25.f${ffhr}.grib2.idx $COMOUT/gfs.t${cyc}z.wafs2_0p25.f${ffhr000}.grib2.idx

  fi

  ######################
  # Distribute Data
  ######################

  # Hazard WAFS data (ICESEV GTG from 100mb to 1000mb) is sent to NOMADS for US stakeholders
  if [ $SENDDBN = "YES" ] ; then
    $DBNROOT/bin/dbn_alert MODEL GFS_WAFS2_0P25_GB2 $job $COMOUT/gfs.t${cyc}z.wafs2_0p25.f${ffhr000}.grib2
  fi

  if [ $FHOUT_GFS -eq 3 ] ; then
      FHINC=03
      if [ $ffhr -ge 48 ] ; then
	  FHINC=06
      fi
  else
      if [ $ffhr -lt 24 ] ; then
          FHINC=01
      elif [ $ffhr -lt 48 ] ; then
          FHINC=03
      else
          FHINC=06
      fi
  fi
  # temporarily set FHINC=03. Will remove this line for 2023 ICAO standard.
  FHINC=03
  ffhr=`expr $ffhr + $FHINC`
  if test $ffhr -lt 10
  then
      ffhr=0${ffhr}
  fi

done

################################################################################
# GOOD RUN
set +x
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
echo "**************JOB EXGFS_ATMOS_WAFS_GRIB2_0P25.SH COMPLETED NORMALLY ON THE IBM"
set -x
################################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"

exit 0

############## END OF SCRIPT #######################

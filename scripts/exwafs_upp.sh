#!/bin/bash

#####################################################################
echo "-----------------------------------------------------"
echo " exwafs_upp.sh" 
echo " Jun 24 - Mao - script for wafs upp"
echo "-----------------------------------------------------"
#####################################################################
set -x

cd $DATA

msg="HAS BEGUN on `hostname`"
postmsg "$msg"

POSTGPSH=${POSTGPSH:-$USHwafs/wafs_upp.sh}
PREFIX=${PREFIX:-${RUNupp}.t${cyc}z}

SUFFIX=".nc"
export MODEL_OUT_FORM=${MODEL_OUT_FORM:-netcdfpara}

export PGBOUT=wafsfile # For UPP Fortran code
export PGIOUT=wafsifile

############################################################
# Post Analysis Files before starting the Forecast Post
############################################################
if [ $fhr = "anl" ]; then
#----------------------------------
    export VDATE=${PDY}${cyc}

    loganl=$COMINgfs/${PREFIX}.atmanl${SUFFIX}

   if test -f $loganl ; then

      [[ -f flxfile ]] && rm flxfile ; [[ -f atmfile ]] && rm atmfile
      ln -fs $COMINgfs/${PREFIX}.atmanl${SUFFIX} atmfile
      export ATMINP=atmfile
      ln -fs $COMINgfs/${PREFIX}.sfcanl${SUFFIX} flxfile
      export FLXINP=flxfile

##########################  WAFS U/V/T analysis start ##########################
# U/V/T on ICAO pressure levels for WAFS verification
      if [[ $RUNupp = gfs ]] ; then

	 #For MDL2P.f, WAFS pressure levels are different from master file
	 export POSTGPVARS="KPO=56,PO=84310.,81200.,78190.,75260.,72430.,69680.,67020.,64440.,61940.,59520.,57180.,54920.,52720.,50600.,48550.,46560.,44650.,42790.,41000.,39270.,37600.,35990.,34430.,32930.,31490.,30090.,28740.,27450.,26200.,25000.,23840.,22730.,21660.,20650.,19680.,18750.,17870.,17040.,16240.,15470.,14750.,14060.,13400.,12770.,12170.,11600.,11050.,10530.,10040.,9570.,9120.,8700.,8280.,7900.,7520.,7170.,popascal=.true.,"

	 export PostFlatFile=$PARMwafs/postxconfig-NT-GFS-WAFS-ANL.txt
	 export CTLFILE=$PARMwafs/postcntrl_gfs_wafs_anl.xml

	 $POSTGPSH
	 export err=$?

	 if [ $err -ne 0 ] ; then
	     echo " *** GFS POST WARNING: WAFS output failed for analysis, err=$err"
	 else

	    # Need to be saved for WAFS U/V/T verification, 
	    # resolution higher than WAFS 1.25 deg for future compatibility
	    wafsgrid="latlon 0:1440:0.25 90:721:-0.25"
	    $WGRIB2 $PGBOUT -set_grib_type same -new_grid_winds earth \
		    -new_grid_interpolation bilinear -set_bitmap 1 \
		    -new_grid $wafsgrid ${PGBOUT}.tmp

	    if test $SENDCOM = "YES"
	    then
		cpfs ${PGBOUT}.tmp $COMOUT/$RUN.t${cyc}z.0p25.anl.grib2
		$WGRIB2 -s ${PGBOUT}.tmp > $COMOUT/$RUN.t${cyc}z.0p25.anl.grib2.idx
	    fi
	    rm $PGBOUT ${PGBOUT}.tmp
	 fi
      fi
   fi
##########################  WAFS U/V/T analysis end  ##########################
else
##########################  WAFS forecast  start ##########################
   export VDATE=`${NDATE} +${fhr} ${PDY}${cyc}`
   [[ -f flxfile ]] && rm flxfile ; [[ -f atmfile ]] && rm atmfile
   ln -fs $COMINgfs/${PREFIX}.atmf${fhr}${SUFFIX} atmfile
   export ATMINP=atmfile
   ln -fs $COMINgfs/${PREFIX}.sfcf${fhr}${SUFFIX} flxfile
   export FLXINP=flxfile
    
   # Generate WAFS products on ICAO standard level.
   # Do not need to be sent out to public, WAFS package will process the data.
   if [[ $RUNupp = gfs  || $RUNupp = gefs ]] ; then

       #For MDL2P.f, WAFS pressure levels are different from master file
       export POSTGPVARS="KPO=58,PO=97720.,90810.,84310.,81200.,78190.,75260.,72430.,69680.,67020.,64440.,61940.,59520.,57180.,54920.,52720.,50600.,48550.,46560.,44650.,42790.,41000.,39270.,37600.,35990.,34430.,32930.,31490.,30090.,28740.,27450.,26200.,25000.,23840.,22730.,21660.,20650.,19680.,18750.,17870.,17040.,16240.,15470.,14750.,14060.,13400.,12770.,12170.,11600.,11050.,10530.,10040.,9570.,9120.,8700.,8280.,7900.,7520.,7170.,popascal=.true.,"

       run=`echo $RUNupp | tr '[a-z]' '[A-Z]'`
       # Extend WAFS u/v/t up to 120 hours
       if [  $fhr -le 48  ] ; then
	   export PostFlatFile=$PARMwafs/postxconfig-NT-${run}-WAFS.txt
	   export CTLFILE=$PARMwafs/postcntrl_${RUNupp}_wafs.xml
       else
	   export PostFlatFile=$PARMwafs/postxconfig-NT-GFS-WAFS-EXT.txt
	   export CTLFILE=$PARMwafs/postcntrl_gfs_wafs_ext.xml
       fi

       # gtg has its own configurations
       #cp $HOMEwafs/sorc/ncep_post.fd/post_gtg.fd/gtg.config.$RUNupp .
       #cp $HOMEwafs/sorc/ncep_post.fd/post_gtg.fd/imprintings.gtg_${RUNupp}.txt .
       #cp $HOMEwafs/sorc/ncep_post.fd/post_gtg.fd/gtg.input.$RUNupp .
       cp $PARMwafs/gtg.config.$RUNupp gtg.config
       cp $PARMwafs/gtg_imprintings.txt gtg_imprintings.txt

       $POSTGPSH

       export err=$?

       if [ $err -ne 0 ] ; then
	   echo " *** GFS POST WARNING: WAFS output failed for f${fhr}, err=$err"
       else
	   if [ -e $PGBOUT ] ; then
	       if [  $SENDCOM = "YES" ] ; then
		   cpfs $PGBOUT $COMOUT/$RUN.t${cyc}z.master.f$fhr.grib2
		   $WGRIB2 -s $PGBOUT > $PGIOUT # WAFS products exist from ush/gfs_nceppost.sh before running anything else
		   cpfs $PGIOUT $COMOUT/$RUN.t${cyc}z.master.f$fhr.grib2.idx
	       fi
           fi
       fi
   fi
   [[ -f wafsfile ]] && rm wafsfile ; [[ -f wafsifile ]] && rm wafsifile

fi
###########################  WAFS forecast end ###########################
echo "PROGRAM IS COMPLETE!!!!!"

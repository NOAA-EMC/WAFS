set -x

# making the time stamp format for ncep post
export YY=`echo $VDATE | cut -c1-4`
export MM=`echo $VDATE | cut -c5-6`
export DD=`echo $VDATE | cut -c7-8`
export HH=`echo $VDATE | cut -c9-10`

run=`echo $RUN | tr '[a-z]' '[A-Z]'`
cat > itag <<EOF
&model_inputs
fileName=$NEMSINP
IOFORM=${MODEL_OUT_FORM}
grib=grib2
DateStr='${YY}-${MM}-${DD}_${HH}:00:00'
MODELNAME=GFS
SUBMODELNAME=$run
fileNameFlux=$FLXINP
/
 &NAMPGB
 $POSTGPVARS
/
EOF

cat itag

rm -f fort.*

cp ${POSTGRB2TBL} .
cp ${PostFlatFile} ./postxconfig-NT.txt


export CTL=`basename $CTLFILE`

cp ${PARMwafs}/nam_micro_lookup.dat ./eta_micro_lookup.dat

echo "wafs_nceppost.sh OMP_NUM_THREADS= $OMP_NUM_THREADS"
${APRUN:-mpirun.lsf} $POSTGPEXEC < itag > outpost_gfs_${VDATE}_${CTL}

export ERR=$?
export err=$ERR

exit $err

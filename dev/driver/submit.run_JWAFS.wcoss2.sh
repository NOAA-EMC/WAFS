job=$1
JOB=`echo $job | tr 'a-z' 'A-Z'`

PDY=20240819
cyc=18

tmpdir=/lfs/h2/emc/ptmp/yali.mao/working_wafs.$job.$PDY
mkdir -p $tmpdir
cd $tmpdir

jobcard=run_JWAFS_$JOB.wcoss2
cp /lfs/h2/emc/vpppg/noscrub/yali.mao/git/WAFS.fork/dev/driver/$jobcard .

if [ $job = 'upp' ] ; then
    FHOURS="anl 000 001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 016 017 018 019 020 021 022 023 024 \
	027 030 033 036 039 042 045 048 054 060 066 072 078 084 090 096 102 108 114 120"
elif [ $job = 'gcip' ] ; then
    FHOURS="000 003"
elif [ $job = 'grib2_0p25' ] ; then
    export FHOUT_GFS=${FHOUT_GFS:-1}
    if [ $FHOUT_GFS -eq 3 ] ; then #27
	export FHOURS=${FHOURS:-"6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 54 60 66 72 78 84 90 96 102 108 114 120"}
    else #39
	export FHOURS=${FHOURS:-"6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 27 30 33 36 39 42 45 48 54 60 66 72 78 84 90 96 102 108 114 120"}
    fi
elif [ $job = 'grib2_1p25' ] ; then
    export FHOURS=${FHOURS:-"00 06 09 12 15 18 21 24 27 30 33 36 42 48 54 60 66 72"}
elif [ $job = 'grib' ] ; then
    export FHOURS=${FHOURS:-"06 12 18 24 30 36 42 48 54 60 66 72"}
elif [ $job = 'grib2_0p25_blending' ] ; then
    export FHOUT_GFS=${FHOUT_GFS:-1}
    if [ $FHOUT_GFS -eq 3 ] ; then
	export FHOURS=${FHOURS:-"6 9 12 15 18 21 24 27 30 33 36 39 42 45 48"}
    else
	export FHOURS=${FHOURS:-"6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 27 30 33 36 39 42 45 48"}
    fi    
fi

for fhr in $FHOURS ; do
    sed -e "s/log.wafs_$job/log.wafs_$job.$fhr/g" \
	-e "s/PDY=.*/PDY=$PDY/g" \
	-e "s/cyc=.*/cyc=$cyc/g" \
	-e "s/fhr=.*/fhr=$fhr/g" \
	-e "s/working_wafs/working_wafs.$job.$PDY/g" \
	$jobcard > $jobcard.$fhr
    qsub $jobcard.$fhr
done

tmpdir=/lfs/h2/emc/ptmp/yali.mao/working_wafs
mkdir -p $tmpdir
cd $tmpdir
cp /lfs/h2/emc/vpppg/noscrub/yali.mao/git/WAFS.fork/dev/driver/run_JWAFS_UPP.wcoss2 .

fhours="anl 000 001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 016 017 018 019 020 021 022 023 024 \
	027 030 033 036 039 042 045 048 054 060 066 072 078 084 090 096 102 108 114 120"

PDY=20240703
for fh in $fhours ; do
    sed -e "s/log.wafs_upp/log.wafs_upp.$fh/g" \
	-e "s/PDY=.*/PDY=$PDY/g" \
	-e "s/fhours=.*/fhours=$fh/g" \
	run_JWAFS_UPP.wcoss2 > run_JWAFS_UPP.wcoss2.$fh
    qsub run_JWAFS_UPP.wcoss2.$fh
done

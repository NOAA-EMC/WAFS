SHELL=/bin/sh
set -x

##################################################################
# wafs using module compile standard
# 06/12/2018 yali.ma@noaa.gov:    Create module load version
##################################################################

module purge
moduledir=`dirname $(readlink -f ../modulefiles/wafs)`
module use ${moduledir}
module load wafs/wafs_v5.0.0.dell
module list

 curdir=`pwd`
 export INC="${G2_INC4}"
 export FC=ifort

# track="-O3 -g -traceback -ftrapuv -check all -fp-stack-check "
# track="-O2 -g -traceback"

 export FFLAGSawc="-FR -I ${G2_INC4} -I ${IP_INC4} -g -O2 -convert big_endian -assume noold_ldout_format"
 export FFLAGSblnd="-O -I ${G2_INC4}"
 export FFLAGST="-O -FR -I ${G2_INC4}"
 export FFLAGSgcip="-FR -I ${G2_INC4} -I ${IP_INC4} -g -O3"
# export FFLAGSgcip="-FR -I ${G2_INC4} -I ${IP_INC4} ${track}"

 export FFLAGScnv="-O3 -g -I ${G2_INC4}"
 export FFLAGSmkwfs="-O3 -g -r8 -i8"

if [ ! -d "../exec" ] ; then
  mkdir -p ../exec
fi

for dir in wafs_awc_wafavn.fd wafs_gcip.fd wafs_blending.fd wafs_makewafs.fd wafs_cnvgrib2.fd wafs_setmissing.fd ; do
 export LIBS="${G2_LIB4} ${W3NCO_LIB4} ${BACIO_LIB4} ${IP_LIB4} ${SP_LIB4} ${JASPER_LIB} ${PNG_LIB} ${Z_LIB}  ${BUFR_LIB4}"
 cd ${curdir}/$dir
 make clean
 make
 make install
 make clean
done



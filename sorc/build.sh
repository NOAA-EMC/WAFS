#!/bin/sh
set -x -e

mac=$(hostname | cut -c1-1)

#---------------------------------------------------------
if [ $mac = t -o $mac = e -o $mac = g ] ; then # For WCOSS
                                                 # --------
 machine=wcoss
 export LIBDIR=/nwprod/lib
 export INC="${G2_INC4}"
 export LIBS="${G2_LIB4} ${W3NCO_LIB4} ${BACIO_LIB4} ${IP_LIB4} ${SP_LIB4} ${JASPER_LIB} ${PNG_LIB} ${Z_LIB}  ${BUFR_LIB4}"
 export FC=ifort

 export FFLAGSawc="-FR -I ${G2_INC4} -g -O2 -convert big_endian -assume noold_ldout_format"
 export FFLAGSblnd="-O -I ${G2_INC4}"
 export FFLAGST="-O -FR -I ${G2_INC4}"
 export FFLAGSgcip="-FR -I ${G2_INC4} -g -O2"

fi

#---------------------------------------------------------
# must be in the same file as 'export'
./install.sh
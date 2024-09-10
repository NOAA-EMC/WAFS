#!/bin/bash

######################################################################
#  UTILITY SCRIPT NAME :  exwafs_grib.sh
#         DATE WRITTEN :  10/04/2004
#
#  Abstract:  This utility script produces the  WAFS GRIB
#
#     Input:  1 arguments are passed to this script.
#             1st argument - Forecast Hour - format of 2I
#
#     Logic:   If we are processing fhrs 12-30, we have the
#              added variable of the a or b in the process accordingly.
#              The other fhrs, the a or b  is dropped.
#
#   History:  Oct 2004 - First implementation of this new script."
#             Aug 2015 - Modified for Phase II"
#             Dec 2015 - Modified for input model data in Grib2"
#             Oct 2021 - Remove jlogfile"
#             May 2024 - WAFS separation"
#####################################################################

set -x

ifhr=$((10#$fhr))

####################################################
#
#    GFS WAFS PRODUCTS MUST RUN IN CERTAIN ORDER
#    BY REQUIREMENT FROM FAA.
#    PLEASE DO NOT ALTER ORDER OF PROCESSING WAFS
#    PRODUCTS CONSULTING WITH MR. BRENT GORDON.
#
####################################################

set +x
echo " "
echo "#####################################"
echo " Process GRIB WAFS PRODUCTS (mkwafs)"
echo " FORECAST HOURS 00 - 72."
echo "#####################################"
echo " "
set -x

cd "${DATA}" || err_exit "FATAL ERROR: Could not 'cd ${DATA}'; ABORT!"

# If we are processing fhrs 12-30, we have the
# added variable of the a  or b in the process.
# The other fhrs, the a or b  is dropped.

if ((ifhr >= 12 && ifhr <= 24)); then
    "${USHwafs}/mkwfsgbl.sh" "${fhr}" a
fi

if ((ifhr == 30)); then
    "${USHwafs}/mkwfsgbl.sh" "${fhr}" a
    for hr in 12 18 24 30; do
        "${USHwafs}/mkwfsgbl.sh" "${hr}" b
    done
    "${USHwafs}/mkwfsgbl.sh" 00 x
    "${USHwafs}/mkwfsgbl.sh" 06 x
fi

if ((ifhr > 30 && ifhr <= 48)); then
    "${USHwafs}/mkwfsgbl.sh" "${fhr}" x
fi

if ((ifhr == 60 || ifhr == 72)); then
    "${USHwafs}/mkwfsgbl.sh" "${fhr}" x
fi

#!/bin/ksh
set -x

iproc=$1
infile=$2
fields=$3
interp=$4

options='-set_bitmap 1 -set_grib_type same -new_grid_winds earth'
$WGRIB2 $infile | egrep "$fields"| $WGRIB2 -i $infile -grib regrid.fields.$iproc
if [ -z $interp ] ; then
    # No interpolation is needed
    mv regrid.fields.$iproc regrid.tmp.$iproc
else
    # Do interpolation for re-gridding
    shift ; shift ; shift ; shift
    newgrid=$@
    $WGRIB2 regrid.fields.$iproc $options -set master_table 6 -new_grid_interpolation $interp -new_grid $newgrid regrid.tmp.$iproc
    rm regrid.fields.$iproc
fi

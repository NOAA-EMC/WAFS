#!/bin/bash
# modulefile for WAFS run
set -x

module load intel/${intel_ver}
module load PrgEnv-intel/${PrgEnvintel_ver}
module load craype/$craype_ver

module load libjpeg/$libjpeg_ver
module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver
module load grib_util/$grib_util_ver
module load wgrib2/$wgrib2_ver

# For make_NTC_file.pl in blending
# module load util_shared/$util_shared_ver

# For GCIP
# module load bufr_dump/$bufr_dump_ver

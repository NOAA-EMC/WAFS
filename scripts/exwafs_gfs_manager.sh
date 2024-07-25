#!/bin/bash
######################################################################
#  UTILITY SCRIPT NAME :  exwafs_gfs_manager.sh
#         DATE WRITTEN :  07/22/2024
#
#  Abstract:  This script manages upstream GFS data
#
# History:  07/22/2024
#              - initial version
#####################################################################

set -x

# Forecast hours for GFS
gfs_fhrs=$(seq -s ' ' 0 1 120)

# Forecast hours for JWAFS_UPP
seq1=$(seq -s ' ' 0 1 24)   # 000 -> 024; 1-hourly
seq2=$(seq -s ' ' 27 3 48)  # 027 -> 048; 3-hourly
seq3=$(seq -s ' ' 54 6 120) # 054 -> 120; 6-hourly
jwafs_upp_fhrs="${seq1} ${seq2} ${seq3}"

# Forecast hours for JWAFS_GRIB; 006 - 072; 6-hourly
jwafs_grib_fhrs=$(seq -s ' ' 6 6 72)

# Forecast hours for JWAFS_GCIP; 000, 003
jwafs_gcip_fhrs="0 3"

# Wait for all forecast hours to finish
MAX_ITER=1080
for ((iter = 1; iter <= MAX_ITER; iter++)); do

  # Loop over all GFS forecast hours
  for fhr in ${gfs_fhrs}; do

    fhr3=$(printf "%03d" "${fhr}")

    # Trigger jobs based on GFS forecast output availability
    if [[ -s "${COMINgfs}/gfs.t${cyc}z.logf${fhr3}.txt" ]]; then

      # Release the JWAFS_UPP analysis job if this is f000
      if ((fhr == 0)); then
        set +x
        echo "Releasing JWAFS_UPP job for analysis"
        set -x
        ecflow_client --event release_wafs_upp_anl
      fi

      # Release JWAFS_UPP forecast job for any forecast hour in the list
      if [[ " ${jwafs_upp_fhrs} " == *" ${fhr} "* ]]; then
        set +x
        echo "Releasing JWAFS_UPP job for fhr=${fhr3}"
        set -x
        ecflow_client --event "release_wafs_upp_${fhr3}"
      fi

      # Release JWAFS_GCIP job
      if [[ " ${jwafs_gcip_fhrs} " == *" ${fhr} "* ]]; then
        set +x
        echo "Releasing JWAFS_GCIP job for fhr=${fhr3}"
        set -x
        ecflow_client --event "release_wafs_gcip_${fhr3}"
      fi

      if [[ " ${jwafs_grib_fhrs} " == *" ${fhr} "* ]]; then
        set +x
        echo "Releasing JWAFS_GRIB job for fhr=${fhr3}"
        set -x
        ecflow_client --event "release_wafs_grib_${fhr3}"
      fi

      # Remove current fhr from list, once all jobs for the current fhr have been triggered
      gfs_fhrs=$(echo "${gfs_fhrs}" | sed "s/${fhr}//")
    fi

  done # end of loop over all GFS forecast hours

  # Check if there are any forecast hours left to process
  check=$(echo "${gfs_fhrs}" | wc -w)
  if ((check == 0)); then
    break
  fi

  # Sleep for 10 seconds before checking again
  sleep 10

done # end of loop over all iterations

if ((iter > MAX_ITER)); then
  msg="FATAL ERROR: ABORTING after 3 hours of waiting for GFS forecast output at hours ${gfs_fhrs}."
  err_exit "${msg}"
fi

echo "HAS COMPLETED NORMALLY!"

exit 0

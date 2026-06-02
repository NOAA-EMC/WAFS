WAFS v7.1.0  RELEASE NOTES

-------
Prelude
-------

This implementation is a WAFS upgrade for GFSv17 upgrade implementation.

Implementation Instructions
---------------------------

The NOAA-EMC and NCAR organization spaces on GitHub are used to manage the WAFS code.  The SPA(s) handling the WAFS implementation need to have permissions to clone the private NCAR UPP_GTG repository.  All NOAA-EMC organization repositories are publicly readable and do not require access permissions.  Please proceed with the following steps to checkout, build, and install the package on WCOSS2:

Checkout the package from GitHub and `cd` into the directory:
```bash
cd ${PACKAGEROOT}
git clone -b wafs.v7.1.0 https://github.com/noaa-emc/wafs wafs.v7.1.0
cd wafs.v7.1.0
./sorc/checkout_upp.sh
```

The checkout procedure extracts the following WAFS components, while GTG is a subcomponent of UPP.:
| Component | Revision             | POC               |
| --------- | -------------------- | ----------------- |
| UPP       | wafs_upp.fd @4552551 | Wen.Meng@noaa.gov |
| GTG       | post_gtg.fd @c49023a | Yali.Mao@noaa.gov |

The GTG repository is private which may protect you from checking out. To inquire the access, please contact the code managers with justification.

To build all the WAFS components, execute:
```bash
./sorc/build_all.sh
```
The `build_all.sh` script compiles all WAFS components including UPP.  Runtime output from the build is written to log files in `sorc/logs` directory. To build an individual program, for instance, `wafs_upp.x`, use `sorc/build_upp.sh`.

Lastly, link the `ecflow` scripts by executing:
```bash
./ecf/setup_ecf_links.sh
```

Version File Changes
--------------------
Updated files: build.ver and run.ver


Sorc Changes
------------
UPP upgrade to github revision #4552551
GTG upgrade to github revision #c49023a

Job Changes
-----------
COMINgfs is updated for GFSv17 filename and subfolder changes.
jobs/JWAFS_GFS_MANAGER
jobs/JWAFS_GCIP
jobs/JWAFS_GRIB
jobs/JWAFS_GRIB2_0P25
jobs/JWAFS_GRIB2_1P25
jobs/JWAFS_UPP

Parm Changes
------------
parm/upp is created after system building:
 - gtg.config.gfs : updated calibrations for GTG because of GFS science changes
 - gtg.input.gfs : new GTG configuration file
 - gtg_imprintings.txt : renamed to imprintings.gtg_gfs.txt, no change
 - nam_micro_lookup.dat : deleted, not needed for WAFS UPP runs
 - postcntrl_gfs_wafs.xml : removed paramset of WAFS on ICAO_STD_SFC
 - postxconfig-NT-GFS-WAFS-ANL.txt : updated for UPP
 - postxconfig-NT-GFS-WAFS-EXT.txt : updated for UPP
 - postxconfig-NT-GFS-WAFS.txt: updated for UPP and removed paramset of WAFS on ICAO_STD_SFC

Script Changes
--------------
GFSv17 filename changes are reflected in the following scripts:
1. scripts/exwafs_gcip.sh, additionally CLWMR is updated to CLMR for a newer version wgrib2 v2.0.8
2. scripts/exwafs_gfs_manager.sh
3. scripts/exwafs_grib2_0p25.sh
4. scripts/exwafs_grib2_1p25.sh
5. scripts/exwafs_upp.sh, additionally script is updated for new 'itag' for upgraded UPP
6. ush/mkwfsgbl.sh

Fix Changes
-----------
No change

Module Changes
--------------
 - Refer to https://docs.google.com/presentation/d/16SQJRjVsYsZOc1BbmYN0WRSYzF50_jbs4TTqVdeybeM/edit?slide=id.g275012a997e_0_2#slide=id.g275012a997e_0_2
 - In sorc/build_upp.sh, add the following line to compile WAFS and its subcomponent UPP with the same modules.
   source "${DIR_ROOT}/versions/build.ver"
 - CMakeLists.txt files are updated to add compatibility for future bacio version upgrades

Changes to File Sizes
---------------------
No change

Environment and Resource Changes
--------------------------------
No change

Pre-implementation Testing Requirements
---------------------------------------
* Which production jobs should be tested as part of this implementation?
  * The entire WAFS v7.1.0 package needs to be installed and tested on WCOSS-2
* Does this change require a 30-day evaluation?
  * Yes


Product Changes
---------------
No change

Dissemination Information
-------------------------
No change

HPSS Archive
------------
No change

Job Dependencies and flow diagram
---------------------------------
No change

Documentation
-------------
* WAFS.V7.1 Implementation Kick-off Meeting Slides https://docs.google.com/presentation/d/16SQJRjVsYsZOc1BbmYN0WRSYzF50_jbs4TTqVdeybeM


Prepared By
-----------
* yali.mao@noaa.gov

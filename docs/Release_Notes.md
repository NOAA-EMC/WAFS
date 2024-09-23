WAFS v7.0.0  RELEASE NOTES

-------
Prelude
-------

This implementation is a separation of the WAFS component from the GFSv16 application, no science change.

Implementation Instructions
---------------------------

The NOAA-EMC and NCAR organization spaces on GitHub are used to manage the WAFS code.  The SPA(s) handling the WAFS implementation need to have permissions to clone the private NCAR UPP_GTG repository.  All NOAA-EMC organization repositories are publicly readable and do not require access permissions.  Please proceed with the following steps to checkout, build, and install the package on WCOSS2:

Checkout the package from GitHub and `cd` into the directory:
```bash
cd ${PACKAGEROOT}
git clone --recursive -b wafs.v7.0.0 https://github.com/noaa-emc/wafs wafs.v7.0.0
cd wafs.v7.0.0
```

The checkout procedure extracts the following WAFS components, while GTG is a subcomponent of UPP.:
| Component | Tag                  | POC               |
| --------- | -------------------- | ----------------- |
| UPP       | upp_wafs_v7.0.0      | Wen.Meng@noaa.gov |
| GTG       | ncep_post_gtg.v2.1.0 | Yali.Mao@noaa.gov |

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
New files: build.ver and run.ver


Sorc Changes
------------
No change from GFSv16

Job Changes
-----------
Filename changes according to EE2 standards:
 |   wafs.v7                   |    GFSv16                     
 |   ------------------------- |    ----------------------------------------------------|
 |   JWAFS_GCIP                |<- JGFS_ATMOS_WAFS_GCIP                                 |
 |   JWAFS_GRIB                |<- JGFS_ATMOS_WAFS                                      |
 |   JWAFS_GRIB2_0P25          |<- JGFS_ATMOS_WAFS_GRIB2_0P25                           |
 |   JWAFS_GRIB2_0P25_BLENDING |<- JGFS_ATMOS_WAFS_BLENDING_0P25                        |
 |   JWAFS_GRIB2_1P25          |<- JGFS_ATMOS_WAFS_GRIB2                                |
 |                             |   JGFS_ATMOS_WAFS_BLENDING (removed after cleaning up) |
 |   JWAFS_GFS_MANAGER (new)   |                                                        |
 |   JWAFS_UPP         (new)   |                                                        |


Parm Changes
------------
1. Remove parm/wafs/legend
2. parm/upp is created after system building. Per AWC request, WAFS UPP control files add 4 low levels for icing and 1 upper lower for turbulence:
   - postxconfig-NT-GFS-WAFS.txt
   - postcntrl_gfs_wafs.xml

Script Changes
--------------
First of all, filename changes according to EE2 standards:
 |   wafs.v7                       |    GFSv16
 |   ----------------------------- |    ---------------------------------------------------------|
 |   exwafs_gcip.sh                |<- exgfs_atmos_wafs_gcip.sh                                  |
 |   exwafs_grib2_0p25_blending.sh |<- exgfs_atmos_wafs_blending_0p25.sh                         |
 |   exwafs_grib2_0p25.sh          |<- exgfs_atmos_wafs_grib2_0p25.sh                            |
 |   exwafs_grib2_1p25.sh          |<- exgfs_atmos_wafs_grib2.sh                                 |
 |   exwafs_grib.sh                |<- exgfs_atmos_wafs_grib.sh                                  |
 |                                 |   exgfs_atmos_wafs_blending.sh (removed after cleaning up)  |
 |   exwafs_gfs_manager.sh (new)   |                                                             |
 |   exwafs_upp.sh (new)           |                                                             |

Additionally there are other changes:
1. In exwafs_grib2_0p25_blending.sh, extend the waiting time window for UK data from 15 to 25 minutes
2. In exwafs_grib2_0p25.sh, only include fields at the extra levels when forecast hour is between 06 and 36 per AWC request
3. In ush/mkwfsgbl.sh: change input dependency from GFS pgrb2.1p00 to master file.
4. Remove files under ush/ folder: wafs_blending.sh wafs_grib2.regrid.sh wafs_intdsk.sh
5. In exwafs_grib2_0p25_blending.sh, remove the condition of sending UK unblended data if US unblended data is missing. It won't happen because the job itself won't get triggered if US unblended data is missing

Fix Changes
-----------
1. Remove fix/wafs/legend folder
2. Remove files under fix/wafs:
   - grib2_blended_wafs_wifs_fFF.0p25
   - grib2_gfs_wafs_wifs_fFF.0p25
   - grib_wafsgfs_intdsk
   - grib_wafsgfs_intdskf00   
3. Under fix/wafs, filenames are changed.
   - faa_gfsmaster.grb2.list   → grib2_gfs_awf_master.list
   - gfs_master.grb2_0p25.list → grib2_0p25_gfs_master2d.list
   - gfs_wafs.grb2_0p25.list   → grib2_0p25_wafs_hazard.list
   - grib2_gfs_awffFF.45       → grib2_gfs_awffFFF.45 (FF FFF - forecast hours)
   - grib2_gfs_wafsfFF.45      → grib2_wafsfFFF.45 (FF FFF - forecast hours)
   - wafs_0p25_admin_msg       → wafs_blending_0p25_admin_msg
   - wafs_gfsmaster.grb2.list  → grib2_wafs.gfs_master.list
   - wafs.namelist             → grib_wafs.namelist

Module Changes
--------------
No change

Changes to File Sizes
---------------------
* UPP: increased by 35G (new, moved from GFS to WAFS)
* GRIB2_0P25: increased by 0.1G

Environment and Resource Changes
--------------------------------
1. Add ecFlow to WAFS package
2. Add UPP as a WAFS component
3. Get rid of MPMD, each forecast hour will be run in its own job card. 
4. WAFS_GRIB job dependency is changed from GFS pgrb2.1p00 to GFS master file.
5. WAFS_GRIB2_0P25_BLENDING runtime decreases from 4 minutes to 0.5 minutes after switching from sequential to parallel run for each forecast hour
6. Package increases from 33M to 288M (increase due to offline UPP source)
7. According to EE2 standards, input data are copied to DATA work folder instead of being soft linked. For this reason, the overall DATA folder size rockets up to 709.6G from 39G

Pre-implementation Testing Requirements
---------------------------------------
* Which production jobs should be tested as part of this implementation?
  * The entire WAFS v7.0.0 package needs to be installed and tested on WCOSS-2
* Does this change require a 30-day evaluation?
  * No


Product Changes
---------------
* Directory changes
  * From com/gfs/v16.3/gfs.YYYYMMDD/CC/atmos to com/wafs/v7.0/wafs.YYYYMMDD/CC
  * Inside WAFS, there are subfolders categoried by job names
    * |-- upp
    * |-- gcip
    * |-- grib
    * |-- grib2
    * |----- 1p25
    * |----- 0p25
    * |-------- blending
* Files to be retired
  * `gfs.tCCz.wafs_icao.grb2fFFF`
  * wafs.tCCz.master.fFFF.grib2 where FFF is from 001 to 005
* File changes
  * For WAFS blending when UK data is missing at multiple forecast hours, multiple files wafs.tCCz.fFFF.wafs_blend_0p25_usonly.emailbody for each forecast hour will replace one single file gfs.tCCz.wafs_blend_0p25_usonly.emailbody for the whole cycle.
* Filename changes
  * Renamed according to EE2 implementation standards
  * Exceptions: files sent to UK keep the original names except forecast hour is changed to 3 digits
  * Details:
    | GFSv16                                 | wafs.v7                                  |
    | -------------------------------------- | ---------------------------------------- |
    | gfs.tCCz.wafs.0p25.anl                 | wafs.tCCz.0p25.anl.grib2                 |
    | gfs.tCCz.wafs.grb2fFFF                 | wafs.tCCz.master.fFFF.grib2              |
    | gfs.tCCz.wafs_0p25_unblended.fFF.grib2 | WAFS_0p25_unblended_YYYYMMDDHHfFFF.grib2 |
    | gfs.tCCz.awf_0p25.fFFF.grib2           | wafs.tCCz.awf.0p25.fFFF.grib2            |
    | gfs.tCCz.awf_grb45fFF.grib2            | wafs.tCCz.awf_grid45.fFFF.grib2          |
    | wmo/grib2.tCCz.awf_grbfFF.45           | wmo/grib2.wafs.tCCz.awf_grid45.fFFF      |
    | gfs.tCCz.wafs_grb45fFF.grib2           | gfs.tCCz.wafs_grb45fFFF.grib2            |
    | wmo/grib2.tCCz.wafs_grbfFF.45          | wmo/grib2.wafs.tCCz.grid45.fFFF          |
    | gfs.tCCz.gcip.fFF.grib2                | wafs.tCCz.gcip.fFFF.grib2                |
    | WAFS_0p25_blended_YYYYMMDDHHfFF.grib2  | WAFS_0p25_blended_ YYYYMMDDHHfFFF.grib2  |
  

* File content changes
  * Add EDPARM CATEDR MWTURB on 127.7 mb, ICESEV on 875.1 908.1 942.1 977.2 mb to:
    * wafs.tCCz.master.fFFF.grib2 when FFF<=048
    * grib2/0p25/wafs.tCCz.awf.0p25.fFFF.grib2 when FFF<=036


Dissemination Information
-------------------------
* dbn_alert subtype changes
  |                                          | GFSv16                | wafs.v7           |
  | ---------------------------------------- | --------------------- |------------------ |
  | gfs.tCCz.wafs_0p25.fFFF.grib2            | GFS_WAFS_0P25_GB2     | WAFS_0P25_GB2     |
  | WAFS_0p25_unblended_YYYYMMDDHHfFFF.grib2 | GFS_WAFS_0P25_UBL_GB2 | WAFS_0P25_UBL_GB2 |
  | wafs.tCCz.awf.0p25.fFFF.grib2            | GFS_AWF_0P25_GB2      | WAFS_AWF_0P25_GB2 |
  | wmo/grib2.wafs.tCCz.awf_grid45.fFFF      | gfs                   | wafs              |
  | gfs.tCCz.wafs_grb45fFFF.grib2            | GFS_WAFS_1P25_GB2     | WAFS_1P25_GB2     |
  | wmo/grib2.wafs.tCCz.grid45.fFFF          | gfs                   | wafs              |
  | WAFS_0p25_blended_ YYYYMMDDHHfFFF.grib2  | GFS_WAFS_0P25_BL_GB2  | WAFS_0P25_BL_GB2  |

* Where should this output be sent?
  * Same as current operations in GFS WAFS
* Who are the users?
  * AWC, UK Met Office, SPC, and ICAO subscribed users
* Which output files should be transferred from PROD WCOSS to DEV WCOSS?
  * All WAFS files should be transferred


HPSS Archive
------------
* Directory changes and filename changes, refer back to 'Product Changes'
* Add wafs.tCCz.0p25.anl.grib2


Job Dependencies and flow diagram
---------------------------------
* Job dependencies refers to this document: https://docs.google.com/spreadsheets/d/1Nt343Z9x9UycweFik3HRFpXkqIjs7m20s15yGOhsgUY/edit?gid=1172497604#gid=1172497604
* Flow diagram refer to page 6 in this document: https://docs.google.com/presentation/d/1yhdTfTHoBvV7K6jR2nfvkNAWn_eDJ2lTvDueRp9C89w/edit#slide=id.g2eeab8aa817_0_0


Documentation
-------------
* WAFS.V7 Implementation Kick-off Meeting Slides https://docs.google.com/presentation/d/1yhdTfTHoBvV7K6jR2nfvkNAWn_eDJ2lTvDueRp9C89w
* WAFSv7 products and dbn_alert: https://docs.google.com/spreadsheets/d/1Nt343Z9x9UycweFik3HRFpXkqIjs7m20s15yGOhsgUY


Prepared By
-----------
* yali.mao@noaa.gov
* rahul.mahajan@noaa.gov
* Hui-Ya.Chuang@noaa.gov

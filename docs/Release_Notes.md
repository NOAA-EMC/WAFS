WAFS v7.0.0  RELEASE NOTES

-------
Prelude
-------

This implementation is a separation of the WAFS component from the GFS application.

Implementation Instructions
---------------------------

The NOAA-EMC and NCAR organization spaces on GitHub are used to manage the WAFS code.  The SPA(s) handling the WAFS implementation need to have permissions to clone the private NCAR UPP_GTG repository.  All NOAA-EMC organization repositories are publicly readable and do not require access permissions.  Please proceed with the following steps to checkout, build, and install the package on WCOSS2:

Checkout the package from GitHub and `cd` into the directory:
```bash
cd ${PACKAGEROOT}
git clone --recursive -b wafs.v7.0.0 https://github.com/noaa-emc/wafs wafs.v7.0.0
cd wafs.v7.0.0
```

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


Sorc Changes
------------


Job Changes
------------


Parm Changes
------------


Script Changes
--------------


Fix Changes
-----------


Module Changes
--------------


Changes to File Sizes
---------------------


Environment and Resource Changes
--------------------------------


Pre-implementation Testing Requirements
---------------------------------------


Dissemination Information
-------------------------


HPSS Archive
------------


Job Dependencies and flow diagram
---------------------------------


Documentation
-------------


Prepared By
-----------
yali.mao@noaa.gov

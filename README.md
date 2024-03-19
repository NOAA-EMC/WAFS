# WAFS
Software necessary to generate WAFS products in the GFS.

To install:

Clone repository:
```bash
git clone https://github.com/noaa-emc/emc_gfs_wafs
```

Move into desired branch and then run:

```bash
./ush/build.sh
```

`build.sh` will detect the platform, load the appropriate modules, build the WAFS executables, and install them under `./install`.


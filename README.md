# WAFS
Software necessary to generate WAFS products

To install:

Clone repository
```bash
git clone https://github.com/NOAA-EMC/WAFS
```

Move into desired branch and then run:

Clone submodule and sub-submodule repository (including upp and upp/sorc/post_gtg):
(gtg code is UCAR private, access needs to be authorized)
```bash
sh sorc/checkout_upp.sh
```

Compile the executable files:
```bash
sh sorc/build_all.sh
```

`build_all.sh` will build WAFS executables and offline UPP executable.


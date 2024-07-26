# WAFS
Software necessary to generate WAFS products

To checkout:
==================================

Way 1:
Clone repository
```bash
git clone https://github.com/NOAA-EMC/WAFS
```

Checkout the desired branch or tag

Clone submodule and sub-submodule repository (including upp and upp/sorc/post_gtg):
(gtg code is UCAR private, access needs to be authorized)
```bash
sh sorc/checkout_upp.sh
```

Way 2:
Recursively clone repository if knowing the desired branch or tag
```bash
git clone --recursive -b desired_branch.or.tag  https://github.com/NOAA-EMC/WAFS
```

To compile:
==================================

Compile the executable files:
```bash
sh sorc/build_all.sh
```

`build_all.sh` will copy the right files, build WAFS executables and offline UPP executable.


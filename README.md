# WAFS
Software necessary to generate WAFS products

To checkout:
==================================

Clone repository
```bash
git clone https://github.com/NOAA-EMC/WAFS
```

Checkout the desired branch or tag

Clone submodule and sub-submodule repository (including upp and upp/sorc/ncep_post.fd/post_gtg.fd):
(gtg code is UCAR private, access needs to be authorized)
```bash
sh sorc/checkout_upp.sh
```

To compile:
==================================

Compile the executable files:
```bash
sh sorc/build_all.sh
```



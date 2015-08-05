dset rh.sample 
undef -9999.9
title sample data on GFS 3D pressure levels
dtype grib 193
options yrev
ydef 721 linear -90.000000 0.25
xdef 1440 linear 0.000000 0.250000
tdef 1 linear 00Z04jun2014 1mo
*  z has 37 levels, for prs
zdef 37 levels
1000 975 950 925 900 875 850 825 800 775 750 725 700 675 650 625 600 575 550 525 500 475 450 425 400 375 350 325 300 275 250 225 200 175 150 125 100
vars 1
v 37 175,100,0 ** (profile) testing data sample [non-dim]
ENDVARS

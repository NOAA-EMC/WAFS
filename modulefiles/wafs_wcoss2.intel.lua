help([[
Build environment for WAFS on WCOSS2
]])

local PrgEnv_intel_ver=os.getenv("PrgEnv_intel_ver")
local intel_ver=os.getenv("intel_ver")
local craype_ver=os.getenv("craype_ver")
local cray_mpich_ver=os.getenv("cray_mpich_ver")
local cmake_ver= os.getenv("cmake_ver")

local jasper_ver=os.getenv("jasper_ver")
local zlib_ver=os.getenv("zlib_ver")
local libpng_ver=os.getenv("libpng_ver")

local bufr_ver=os.getenv("bufr_ver")
local bacio_ver=os.getenv("bacio_ver")
local w3emc_ver=os.getenv("w3emc_ver")
local sp_ver=os.getenv("sp_ver")
local ip_ver=os.getenv("ip_ver")
local g2_ver=os.getenv("g2_ver")

load(pathJoin("PrgEnv-intel", PrgEnv_intel_ver))
load(pathJoin("intel", intel_ver))
load(pathJoin("craype", craype_ver))
load(pathJoin("cray-mpich", cray_mpich_ver))
load(pathJoin("cmake", cmake_ver))

load(pathJoin("jasper", jasper_ver))
load(pathJoin("zlib", zlib_ver))
load(pathJoin("libpng", libpng_ver))

load(pathJoin("bufr", bufr_ver))
load(pathJoin("bacio", bacio_ver))
load(pathJoin("w3emc", w3emc_ver))
load(pathJoin("sp", sp_ver))
load(pathJoin("ip", ip_ver))
load(pathJoin("g2", g2_ver))

whatis("Description: WAFS environment on WCOSS2 with Intel Compilers")

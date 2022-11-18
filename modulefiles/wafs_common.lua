help([[
Load common modules to build WAFS on all machines
]])

local bufr_ver=os.getenv("bufr_ver") or "11.7.0"
local bacio_ver=os.getenv("bacio_ver") or "2.4.1"
local w3emc_ver=os.getenv("w3emc_ver") or "2.9.2"
local sp_ver=os.getenv("sp_ver") or "2.3.3"
local ip_ver=os.getenv("ip_ver") or "3.3.3"
local g2_ver=os.getenv("g2_ver") or "3.4.5"

load(pathJoin("bufr", bufr_ver))
load(pathJoin("bacio", bacio_ver))
load(pathJoin("w3emc", w3emc_ver))
load(pathJoin("sp", sp_ver))
load(pathJoin("ip", ip_ver))
load(pathJoin("g2", g2_ver))

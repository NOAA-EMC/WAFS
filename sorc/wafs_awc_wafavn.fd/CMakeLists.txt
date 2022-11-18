list(APPEND fortran_src
cfgini.f90
funcphys.f90
fuzzy.f90
getoptions.f90
kinds.f90
physcons.f90
tokenize.f90
waf_calc.f90
waf_cat.f90
waf_cb.f90
waf_config.f90
waf_filter.f90
waf_gfip.f90
waf_glob.f90
waf_grib1.f90
waf_grib2.f90
waf_icng.f90
waf_main.f90
waf_phys.f90
waf_tcld.f90
)

if(CMAKE_Fortran_COMPILER_ID MATCHES "^(Intel)$")
  set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -FR -convert big_endian -assume noold_ldout_format")
elseif(CMAKE_Fortran_COMPILER_ID MATCHES "^(GNU)$")
  set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fconvert=big-endian")
endif()

set(exe_name wafs_awc_wafavn.x)
add_executable(${exe_name} ${fortran_src})
target_link_libraries(
  ${exe_name}
  g2::g2_4
  w3emc::w3emc_4
  bacio::bacio_4
  ip::ip_4
  sp::sp_4
)

install(TARGETS ${exe_name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

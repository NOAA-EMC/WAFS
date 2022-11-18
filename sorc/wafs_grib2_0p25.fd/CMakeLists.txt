list(APPEND fortran_src
wafsgrib2.f90
)

set(exe_name wafs_grib2_0p25.x)
add_executable(${exe_name} ${fortran_src})
target_link_libraries(
  ${exe_name}
  g2::g2_4
  bacio::bacio_4
  w3emc::w3emc_4
)

install(TARGETS ${exe_name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

list(APPEND fortran_src
blending.f
prvtime.f
prlevel.f
write_ndfd_grib2.f90
)

set(exe_name wafs_blending.x)
add_executable(${exe_name} ${fortran_src})
target_link_libraries(
  ${exe_name}
  g2::g2_4
  w3nco::w3nco_4
  bacio::bacio_4
)

install(TARGETS ${exe_name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

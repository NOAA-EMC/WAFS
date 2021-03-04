list(APPEND fortran_src
setmissing.f90
)

set(exe_name wafs_setmissing.x)
add_executable(${exe_name} ${fortran_src})
target_link_libraries(
  ${exe_name}
  g2::g2_4
  bacio::bacio_4
  w3nco::w3nco_4
)

install(TARGETS ${exe_name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

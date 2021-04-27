list(APPEND fortran_src
algo.f90
config.f90
derived_fields.f90
gcip.f90
grib1.f90
grib2.f90
gridtemplate.f90
hybrid2pressure.f90
icing.f90
kinds.f90
lightning.f90
makefile
metar.f90
model.f90
pirep.f90
pressure2flight.f90
quicksort.f90
radar.f90
satellite.f90
)

if(CMAKE_Fortran_COMPILER_ID MATCHES "^(Intel)$")
  set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -FR")
endif()

set(exe_name wafs_gcip.x)
add_executable(${exe_name} ${fortran_src})
target_link_libraries(
  ${exe_name}
  g2::g2_4
  ip::ip_4
  sp::sp_4
  w3nco::w3nco_4
  bacio::bacio_4
  bufr::bufr_4_DA
)

install(TARGETS ${exe_name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

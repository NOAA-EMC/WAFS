list(APPEND fortran_src
cnvwafs12.f
cnvwafs21.f
cnvwafs22.f
gds2gdt.f
gdt2gds.f
makepds.f
makepdsens.f
pds2pdt.f
pds2pdtens.f
putgbexn.f
setbit.f
wafs_cnvgrib2.f
)

set(exe_name wafs_cnvgrib2.x)
add_executable(${exe_name} ${fortran_src})
target_link_libraries(
  ${exe_name}
  g2::g2_4
  bacio::bacio_4
  w3emc::w3emc_4
)

install(TARGETS ${exe_name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

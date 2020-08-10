module wafsgrib2
! ABSTRACT: This program reads WAFS fields, change to grib2 template 5.40
!           and relabel pressure levels to exact numbers
!
! PROGRAM HISTORY LOG:
! 2020-04-21  Y Mao
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
  use grib_mod
  use params

! values of product def template needed to read data from GRIB 2 file
  type pdt_t
     integer :: npdt   ! number of template 4
     integer :: icat   ! catogory
     integer :: iprm   ! parameter
     integer :: ilev   ! type of level (code table 4.5)
  end type pdt_t
! PDT parameters in the input GRIB2 file (template 4 number, category, parameter, type of level)
  type(pdt_t), parameter :: &
       pdt_cbcov = pdt_t(0, 6, 25, 10), &
       pdt_cbbot = pdt_t(0, 3, 3, 11), &
       pdt_cbtop = pdt_t(0, 3, 3, 12), &
       pdt_gtg   = pdt_t(0, 19, 30, 100), &
       pdt_icing = pdt_t(0, 19, 37, 100)

! values used to write data to GRIB 2 file
  type gparms_t
     integer :: npdt   ! number of template 4
     integer :: icat   ! catogory
     integer :: iprm   ! parameter
     integer :: ilev   ! type of level (code table 4.5)
     !
     integer :: ndrt   ! number of template 5
     integer :: drt2   ! Binary scale factor
     integer :: drt3   ! Decimal scale factor
     integer :: drt4   ! Number of bits to hold data
     !
     logical :: bitmap           ! whether to use bitmap for sparse data
  end type gparms_t

  type(gparms_t), parameter :: &
       cbcov_gparms = gparms_t(0,6,25,10,40,0,3,10,.true.),&
       cbbot_gparms = gparms_t(0,3,3,11,40,13,5,16,.true.),&
       cbtop_gparms = gparms_t(0,3,3,12,40,14,5,16,.true.),&
       gtg_gparms   = gparms_t(0,19,30,100,40,0,2,8,.false.),&
       icing_gparms = gparms_t(0,19,37,100,40,0,2,8,.false.)

contains

!----------------------------------------------------------------------------
  subroutine process(gfile1, gfile2)
! reads input data
    implicit none
    character(*), intent(in) :: gfile1,gfile2

    integer :: ifl1,ifl2

    integer :: iret, nxy
    type(gribfield) :: gfld,gfld1

    integer, parameter :: NP=31
    integer, parameter :: interval=25 ! every 25mb, from 100mb to 850mb
    integer :: ilevels1(NP),ilevels2(NP), ilevel, i

    call getlun90(ifl1,1)
    call getlun90(ifl2,1)

    print *, "GRIB2 0P25 file handles=",ifl1,ifl2

    CALL BAOPENR(ifl1,gfile1,iret)
    if(iret/=0)print*,'cant open ',trim(gfile1)

    call baopenw(ifl2,gfile2,iret)
    print*,'Opened ',ifl2,'for grib2 data  ', &
           trim(gfile2), 'return code is ',iret

! For icing severity and GTG turbulence, 
! 1. Change template 5 version to 5.40, by icing_gparms and gtg_gparms
! 2. Relabel pressure levels from reference to exact numbers
    do i = 1, NP ! From 100mb to 850mb
       ilevels1(i) = 100*(100+(i-1)*interval)
       ilevels2(i) = ilevels1(i)
       if(ilevels1(i) == 10000) ilevels2(i)=10040
       if(ilevels1(i) == 12500) ilevels2(i)=12770
       if(ilevels1(i) == 15000) ilevels2(i)=14750
       if(ilevels1(i) == 17500) ilevels2(i)=17870
       if(ilevels1(i) == 20000) ilevels2(i)=19680
       if(ilevels1(i) == 22500) ilevels2(i)=22730
       if(ilevels1(i) == 27500) ilevels2(i)=27450
       if(ilevels1(i) == 30000) ilevels2(i)=30090
       if(ilevels1(i) == 35000) ilevels2(i)=34430
       if(ilevels1(i) == 40000) ilevels2(i)=39270
       if(ilevels1(i) == 45000) ilevels2(i)=44650
       if(ilevels1(i) == 50000) ilevels2(i)=50600
       if(ilevels1(i) == 60000) ilevels2(i)=59520
       if(ilevels1(i) == 70000) ilevels2(i)=69680
       if(ilevels1(i) == 75000) ilevels2(i)=75260
       if(ilevels1(i) == 80000) ilevels2(i)=81200
       if(ilevels1(i) == 85000) ilevels2(i)=84310
    end do
    do i = 1, NP
       ilevel = ilevels1(i)
       call get_grib2(ifl1,pdt_icing,ilevel,gfld,nxy,iret)
       ilevel = ilevels2(i)
       call put_grib2(ifl2,icing_gparms,ilevel,gfld,gfld%ibmap,gfld%bmap,gfld%fld,iret)
    end do
    do i = 1, NP
       ilevel = ilevels1(i)    
       call get_grib2(ifl1,pdt_gtg, ilevel,gfld1,nxy,iret)
       ilevel = ilevels2(i)
       call put_grib2(ifl2,  gtg_gparms,ilevel,gfld,gfld1%ibmap,gfld1%bmap,gfld1%fld,iret)
    end do

! For CB, change template 5 version to 5.40, by cbcov_gparm, cbbot_gparm, cbtop_gparm
    call get_grib2(ifl1,pdt_cbcov,0,gfld,nxy,iret)
    call put_grib2(ifl2,cbcov_gparms,0,gfld, gfld%ibmap,gfld%bmap,gfld%fld,iret)

    call get_grib2(ifl1,pdt_cbbot,0,gfld,nxy,iret)
    call put_grib2(ifl2,cbbot_gparms,0,gfld, gfld%ibmap,gfld%bmap,gfld%fld,iret)

    call get_grib2(ifl1,pdt_cbtop,0,gfld,nxy,iret)
    call put_grib2(ifl2,cbtop_gparms,0,gfld, gfld%ibmap,gfld%bmap,gfld%fld,iret)

    call BACLOSE(ifl1, iret)
    call BACLOSE(ifl2, iret)

  end subroutine process

  SUBROUTINE GETLUN90(LUN,OPTN)
!* THIS PROGRAM GETS UNIQUE LOGICAL UNIT NUMBERS FOR OPFILE
!* OR RETURNS THEM TO THE POOL FOR CLFILE
    IMPLICIT NONE
    INTEGER, PARAMETER :: CNCT=1,DSCT=2
    INTEGER :: LUN,OPTN,I
    INTEGER :: NUM(80)=(/ &
                  99,98,97,96,95,94,93,92,91,90, &
                  89,88,87,86,85,84,83,82,81,80, &
                  79,78,77,76,75,74,73,72,71,70, &
                  69,68,67,66,65,64,63,62,61,60, &
                  59,58,57,56,55,54,53,52,51,50, &
                  49,48,47,46,45,44,43,42,41,40, &
                  39,38,37,36,35,34,33,32,31,30, &
                  29,28,27,26,25,24,23,22,21,20 /)
!* START
    IF(OPTN == CNCT) THEN
       DO I=1,80
          IF(NUM(I)>0) THEN
             LUN=NUM(I)
             NUM(I)=-NUM(I)
             return
          ENDIF
       END DO
       PRINT*, 'NEED MORE THAN 80 UNIT NUMBERS'
    ELSE IF(OPTN == DSCT) THEN
!* MAKE THE NUMBER AVAILABLE BY SETTING POSITIVE
       DO I=1,80
          IF(LUN == -NUM(I)) NUM(I)=ABS(NUM(I))
       ENDDO
    END IF

    RETURN
  END SUBROUTINE GETLUN90

!----------------------------------------------------------------------------
  subroutine get_grib2(iunit,pdt, pres_level, gfld, nxy, iret)
    implicit none
    integer, intent(in) :: iunit
    type(pdt_t), intent(in) :: pdt
    integer, intent(in) :: pres_level ! pressure level in Pa
    type(gribfield), intent(out) :: gfld
    integer, intent(out) :: nxy
    integer, intent(out) :: iret

    integer j,jdisc,jpdtn,jgdtn
    integer,dimension(200) :: jids,jpdt,jgdt
    logical :: unpack

    integer :: i

    j        = 0          ! search from 0
    jdisc    = 0          ! for met field:0 hydro: 1, land: 2
    jids(:)  = -9999
    !-- set product defination template 4
    jpdtn    = pdt%npdt   ! number of product defination template 4
    jpdt(:)  = -9999
    jpdt(1)  = pdt%icat   ! category 
    jpdt(2)  = pdt%iprm   ! parameter number
    jpdt(10) = pdt%ilev   ! type of level (code table 4.5)
    jpdt(12) = pres_level ! level value
    !-- set grid defination template/section 3
    jgdtn    = -1  
    jgdt(:)  = -9999
    unpack=.true.
    ! Get field from file
    if(jpdtn == 8) then
       do i = 1, 6 ! Bucket precip accumulation time up to 6 hour
          jpdt(27) = i
          call getgb2(iunit, 0, j, jdisc, jids, jpdtn, jpdt, &
               jgdtn, jgdt, unpack, j, gfld, iret)
          if( iret == 0) then
             nxy = gfld%igdtmpl(8) * gfld%igdtmpl(9)
             gfld%ipdtmpl(9)=gfld%ipdtmpl(9)+i
             print *, "nxy=",nxy,"at bucket accumulation time=",i
             exit
          else
             print *,'call get_grib2, iret=',iret, pdt
          endif
       end do
    else
       call getgb2(iunit, 0, j, jdisc, jids, jpdtn, jpdt, &
            jgdtn, jgdt, unpack, j, gfld, iret)
       if( iret /= 0) then
          print *,'call get_grib2, iret=',iret, pdt,"on level=",pres_level 
       else
          nxy = gfld%igdtmpl(8) * gfld%igdtmpl(9)
       endif
    end if

  end subroutine get_grib2

!----------------------------------------------------------------------------
  subroutine put_grib2(ifl,parms, nlevel, gfld, ibmap,bmap,fld, iret)
! basically the same as putgb2, but with flexible template 4 and template 5
! writes calculated values for one field at all pressure levels
    implicit none
    integer, intent(in) :: ifl
    type(gparms_t), intent(in) :: parms    ! grib2 parameters of template 4 & 5
    integer, intent(in) :: nlevel          ! pressure level in Pa, integer
    type(gribfield), intent(in) :: gfld    ! a sample input carrying information
    integer, intent(in) :: ibmap ! indicator whether to use bitmap
    logical*1, intent(in) :: bmap(:)
    real(4), intent(in) :: fld(:)     ! the data to be written
    integer, intent(out) :: iret           ! return status code  

    CHARACTER(LEN=1),ALLOCATABLE,DIMENSION(:) :: CGRIB
    integer(4) :: lcgrib, lengrib
    integer :: listsec0(2)
    integer :: igds(5)
    real    :: coordlist=0.0
    integer :: ilistopt=0
    ! flexible arrays of template 4, 5
    integer, allocatable :: ipdtmpl(:), idrtmpl(:)

    character(len=*), parameter :: myself = 'put_grib2(): '

!   ALLOCATE ARRAY FOR GRIB2 FIELD
    lcgrib=gfld%ngrdpts*4
    allocate(cgrib(lcgrib),stat=iret)
    if ( iret/=0 ) then
       print *, myself, iret
       iret=2
    endif
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  CREATE NEW MESSAGE
    listsec0(1)=gfld%discipline
    listsec0(2)=gfld%version
    if ( associated(gfld%idsect) ) then
       call gribcreate(cgrib,lcgrib,listsec0,gfld%idsect,iret)
       if (iret /= 0) then
          write(*,*) myself, ' ERROR creating new GRIB2 field = ',iret
       endif
    else
       print *, myself, ' No Section 1 info available. '
       iret=10
       deallocate(cgrib)
       return
    endif
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  ADD GRID TO GRIB2 MESSAGE (Grid Definition Section 3)
    igds(1)=gfld%griddef    ! Source of grid definition (see Code Table 3.0)
    igds(2)=gfld%ngrdpts    ! Number of grid points in the defined grid.
    igds(3)=gfld%numoct_opt ! Number of octets needed for each additional grid points definition
    igds(4)=gfld%interp_opt ! Interpretation of list for optional points definition (Code Table 3.11)
    igds(5)=gfld%igdtnum    ! Grid Definition Template Number (Code Table3.1)
    if ( associated(gfld%igdtmpl) ) then
       call addgrid(cgrib, lcgrib, igds, gfld%igdtmpl, gfld%igdtlen,&
                   ilistopt, gfld%num_opt, iret)
       if (iret/=0) then
          write(*,*) myself, ' ERROR adding grid info = ',iret
       endif
    else
       print *, myself, ' No GDT info available. '
       iret=11
       deallocate(cgrib)
       return
    endif
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  ADD DATA FIELD TO GRIB2 MESSAGE
    ! template 4
    allocate(ipdtmpl(15))
    ipdtmpl(1:15) = gfld%ipdtmpl(1:15)
    ipdtmpl(1)    = parms%icat
    ipdtmpl(2)    = parms%iprm
    ipdtmpl(10)   = parms%ilev
    ipdtmpl(12)   = nlevel
    ! template 5
    if( parms%ndrt == 40) then
       allocate(idrtmpl(7))
    endif
    idrtmpl(1) = 0 ! Any value. Will be overwritten
    idrtmpl(2) = parms%drt2
    idrtmpl(3) = parms%drt3
    idrtmpl(4) = parms%drt4
    idrtmpl(5) = 0
    idrtmpl(6) = 0
    idrtmpl(7) = 255
    ! call addfield
    call addfield(cgrib, lcgrib, parms%npdt, ipdtmpl, & 
                  size(ipdtmpl), coordlist, gfld%num_coord, &
                  parms%ndrt, idrtmpl, size(idrtmpl), &
                  fld, gfld%ngrdpts, ibmap, bmap, iret)
    if (iret /= 0) then
       write(*,*) myself, 'ERROR adding data field = ',iret
    endif
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    !  CLOSE GRIB2 MESSAGE AND WRITE TO FILE
    call gribend(cgrib, lcgrib, lengrib, iret)
    call wryte(ifl, lengrib, cgrib)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    deallocate(cgrib)
    deallocate(ipdtmpl)
    deallocate(idrtmpl)
    RETURN
  end subroutine put_grib2

end module wafsgrib2

program main

  use wafsgrib2

  implicit none

  character(60) :: gfile1,gfile2

  INTEGER :: NARG

  call start()

! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  GET ARGUMENTS
  NARG=IARGC()
  IF(NARG /= 2) THEN
     CALL ERRMSG('wafs_grib2_0p25:  Incorrect usage')
     CALL ERRMSG('Usage: wafs_grib2_0p25 grib2file1 grib2file2')
     CALL ERREXIT(2)
  ENDIF

  CALL GETARG(1,gfile1)
  CALL GETARG(2,gfile2)

  call process(trim(gfile1),trim(gfile2))

end program main


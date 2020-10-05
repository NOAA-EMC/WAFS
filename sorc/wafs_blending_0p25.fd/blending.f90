module blending
! ABSTRACT: This program reads GRIB2 file and makes inventory
!           of GRIB2 file 
!
! PROGRAM HISTORY LOG:
! 2020-01-21  Y Mao
!
! SUBPROGRAMS CALLED: (LIST ALL CALLED FROM ANYWHERE IN CODES)
! LIBRARY:
!       G2LIB    - GB_INFO, GT_GETFLD, PRLEVEL, PRVTIME
!       W3LIB    - GBYTE, SKGB
!       BACIO    - BAOPENR, BAREAD, BACLOSE
!       SYSTEM   - IARGC   FUNCTION RETURNS NUMBER OF ARGUMENT ON
!                          COMMAND LINE
!                - GETARG  ROUTINE RETURNS COMMAND LINE ARGUMENT
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
! No bit-map will be used for blended output
!
! Turbulence blending:
! Max of UK US
!
! Icing severity blending:
! 0. Select pressures
! 1. Max of UK US
! 2. Blend by Gaussian Kernel Filter (sigma=1)
! 3. Keep the original matching data
! 4. Re-categorize by different thresholds
! 5. Not greater than max, and not smaller than min of US and UK
!
! CB blending:
! 1. extent: average
! 2. base: min
! 3. top: max

contains

  subroutine process(gfile1,gfile2,gfile3)
    use grib_mod
    use params

    implicit none

    character(*), intent(in) :: gfile1,gfile2,gfile3

    INTEGER :: NARG
    integer :: ifl1,ifl2,ifl3

    integer, parameter :: msk1=32000
    real, parameter :: EPSILON=0.000001

    integer :: currlen=0,icount,itot
    integer :: iseek,lskip,lgrib,lengrib
    CHARACTER(len=1),allocatable,dimension(:) :: cgrib
    integer :: listsec0(3),listsec1(13)
    integer :: numfields,numlocal,maxlocal
    integer :: ierr,n,k,im,jm,i,j,jj,ij
    logical :: unpack,expand
    character(len=8) :: pabbrev
    integer :: jids(20),jpdt(20),jgdt(20)
    integer :: jpdtn,jgdtn
    type(gribfield) :: gfld,gfld2
    real, allocatable :: usdata(:,:),ukdata(:,:),blddata(:)
    real :: missing
    character(3) :: whichblnd
    logical :: exclusive
    real :: fldmax,fldmin,sum

    unpack=.true.
    expand=.true.
      
    call getlun90(ifl1,1)
    call getlun90(ifl2,1)
    call getlun90(ifl3,1)

    print *, "blended file handles=",ifl1,ifl2,ifl3

    CALL BAOPENR(ifl1,gfile1,ierr)
    if(ierr/=0)print*,'cant open ',trim(gfile1)

    CALL BAOPENR(ifl2,gfile2,ierr)
    if(ierr/=0)print*,'cant open ',trim(gfile2)

    call baopenw(ifl3,gfile3,ierr)
    print*,'Opened ',ifl3,'for grib2 data  ', &
           trim(gfile3), 'return code is ',ierr

    itot=0
    icount=0
    iseek=0
    do
       call skgb(ifl1,iseek,msk1,lskip,lgrib)
       if (lgrib==0) exit    ! end loop at EOF or problem
       if (lgrib>currlen) then
          if (allocated(cgrib)) deallocate(cgrib)
          allocate(cgrib(lgrib),stat=ierr)
          currlen=lgrib
       endif
       call baread(ifl1,lskip,lgrib,lengrib,cgrib)
       if (lgrib/=lengrib) then
          print *,' degrib2: IO Error.'
          call errexit(9)
       endif
       iseek=lskip+lgrib
       icount=icount+1
       PRINT *
       PRINT *,'GRIB MESSAGE ',icount,' starts at',lskip+1
       PRINT *

       ! Unpack GRIB2 field
       call gb_info(cgrib,lengrib,listsec0,listsec1,&
                    numfields,numlocal,maxlocal,ierr)
       if (ierr/=0) then
          write(6,*) ' ERROR querying GRIB2 message = ',ierr
          stop 10
       endif
       itot=itot+numfields
       print *,' SECTION 0: ',(listsec0(j),j=1,3)
       print *,' SECTION 1: ',(listsec1(j),j=1,13)
       print *,' Contains ',numlocal,' Local Sections ', &
               ' and ',numfields,' data fields.'

       do n=1,numfields
          call gf_getfld(cgrib,lengrib,n,unpack,expand,gfld,ierr)
          if (ierr/=0) then
             write(6,*) ' ERROR extracting field = ',ierr
             cycle
          endif

          ! specify missing data values for different fields
          ! don't process fields other than icing, turublence, and CB
          ! 1. For icing severity and GTG, max of UK US
          ! 2. For CB top, max of US UK
          ! 3. For CB base, min of US UK
          ! 4. For CB extent, average of US UK
          if(     gfld%ipdtmpl(1)==19 .and. gfld%ipdtmpl(2)==37)then  ! ICESEV
             missing=-1.
             whichblnd='max'
             exclusive=.true.
          else if(gfld%ipdtmpl(1)==19 .and. gfld%ipdtmpl(2)==30)then  ! EDPARM
             missing=-0.5
             whichblnd='max'
             exclusive=.true.
          else if(gfld%ipdtmpl(1)==19 .and. gfld%ipdtmpl(2)==29)then  ! CATEDR   
             missing=-0.5
             whichblnd='max'
             exclusive=.true.
          else if(gfld%ipdtmpl(1)==19 .and. gfld%ipdtmpl(2)==28)then  ! MWTURB
             missing=-0.5
             whichblnd='max'
             exclusive=.true.
          else if(gfld%ipdtmpl(1)== 6 .and. gfld%ipdtmpl(2)==25)then  ! CB extent
             missing=-0.1
             whichblnd='avg'
             exclusive=.false.
          else if(gfld%ipdtmpl(2)== 3 .and. gfld%ipdtmpl(10)==11)then  ! CB base
             missing=-1.
             whichblnd='min'
             exclusive=.false.
          else if(gfld%ipdtmpl(2)== 3 .and. gfld%ipdtmpl(10)==12)then  ! CB top
             missing=-1.
             whichblnd='max'
             exclusive=.false.
          else
             cycle
          end if
	 
          print *
          print *,' FIELD ',n
          if (n==1) then
             print *,' SECTION 0: ',gfld%discipline,gfld%version
             print *,' SECTION 1: ',(gfld%idsect(j),j=1,gfld%idsectlen)
          endif
          if ( associated(gfld%local).AND.gfld%locallen>0 ) then
             print *,' SECTION 2: ',gfld%locallen,' bytes'
          endif
          print *,' SECTION 3: ',gfld%griddef,gfld%ngrdpts, &
                  gfld%numoct_opt,gfld%interp_opt,gfld%igdtnum
          print *,' GRID TEMPLATE 3.',gfld%igdtnum,': ', &
                  (gfld%igdtmpl(j),j=1,gfld%igdtlen)
          if ( gfld%num_opt == 0 ) then
             print *,' NO Optional List Defining Number of Data Points.'
          else
             print *,' Section 3 Optional List: ', &
                     (gfld%list_opt(j),j=1,gfld%num_opt)
          endif
          print *,' PRODUCT TEMPLATE 4.',gfld%ipdtnum,': ', &
                  (gfld%ipdtmpl(j),j=1,gfld%ipdtlen)

          pabbrev=param_get_abbrev(gfld%discipline,gfld%ipdtmpl(1),&
                  gfld%ipdtmpl(2))
          if ( gfld%num_coord == 0 ) then
             print *,' NO Optional Vertical Coordinate List.'
          else
             print *,' Section 4 Optional Coordinates: ',&
                     (gfld%coord_list(j),j=1,gfld%num_coord)
          endif
          if ( gfld%ibmap /= 255 ) then
             print *,' Num. of Data Points = ',gfld%ndpts, &
                     '    with BIT-MAP ',gfld%ibmap
          else
             print *,' Num. of Data Points = ',gfld%ndpts, &
                     '    NO BIT-MAP '
          endif
          print *,' DRS TEMPLATE 5.',gfld%idrtnum,': ', &
                  (gfld%idrtmpl(j),j=1,gfld%idrtlen)
          fldmax=gfld%fld(1)
          fldmin=gfld%fld(1)
          sum=gfld%fld(1)
          do j=2,gfld%ndpts
             if (gfld%fld(j)>fldmax) fldmax=gfld%fld(j)
             if (gfld%fld(j)<fldmin) fldmin=gfld%fld(j)
             sum=sum+gfld%fld(j)
          enddo
          print *,' Data Values:'
          write(6,fmt='("  MIN=",f21.8,"  AVE=",f21.8, &
               "  MAX=",f21.8)') fldmin,sum/gfld%ndpts,fldmax

          ! read UK's matching products
          print*,'reading UK WAFS'
          jids= -9999
!         jids(5)=listsec1(5)
          jids(6)=listsec1(6) ! year
          jids(7)=listsec1(7) ! mon
          jids(8)=listsec1(8) ! day
          jids(9)=listsec1(9) ! hr
          print*,'disipline,jpd= ',listsec0(1),jids(6:9)
          jpdtn=gfld%ipdtnum
          jpdt=-9999
          jpdt(1)=gfld%ipdtmpl(1) ! cat number
          jpdt(2)=gfld%ipdtmpl(2) ! parm number
          jpdt(3)=gfld%ipdtmpl(3) ! (0-analysis, 1-forecast, or 2-analysis error)
          jpdt(9)=gfld%ipdtmpl(9)   ! forecast hour
          jpdt(10)=gfld%ipdtmpl(10) ! level ID
          jpdt(12)=gfld%ipdtmpl(12) ! level value
          if(gfld%ipdtlen>=16) jpdt(16)=gfld%ipdtmpl(16) ! spatial statistical processing
          print*,'jpdtn,jpdt= ',jpdtn,jpdt(1:10)

          jgdtn=gfld%igdtnum
          jgdt=-9999
!          jgdt(1)=gfld%igdtmpl(1)
          jgdt(8)=gfld%igdtmpl(8)
          jgdt(9)=gfld%igdtmpl(9)
          print*,'jgdtn,jgdt= ',jgdtn,jgdt(1:9)
          call getgb2(ifl2,0,0,listsec0(1),jids,jpdtn,jpdt, &
               gfld%igdtnum,jgdt,.TRUE.,k,gfld2,ierr)
          print*,'US and UK dimensions= ',gfld%ndpts,gfld2%ndpts,"ierr=",ierr

          im=gfld%igdtmpl(8)
          jm=gfld%igdtmpl(9)
          allocate(blddata(im*jm))

          if_ierr: if(ierr==0)then
	   
             allocate(usdata(im,jm))
             allocate(ukdata(im,jm))
             do j=1,jm
                if(gfld%igdtmpl(12) == gfld2%igdtmpl(12)) then ! for template 3.0
                   jj=j
                else
                   jj=jm-j+1  ! UK data is from south to north while US data from north to south
                endif
                do i=1,im
                   usdata(i,j)=gfld%fld((j-1)*im+i)
                   ukdata(i,j)=gfld2%fld((jj-1)*im+i)

                   ij=(j-1)*im+i

                   if(gfld%ibmap /= 255) then !If US with BIT-MAP
                      if(.not. gfld%bmap(ij)) usdata(i,j)=missing
                   endif
                   if(gfld2%ibmap /= 255) then !If UK with BIT-MAP
                      if(.not. gfld2%bmap(ij)) ukdata(i,j)=missing
                   end if
                   blddata(ij)=generalblending(whichblnd,missing,exclusive,usdata(i,j),ukdata(i,j))
                end do
             end do

             j=jm/2
             print*,'sample 2D data ',(i,j,usdata(i,j),ukdata(i,j),i=210,220)

             ! Icing severity needs more processes.
             if(gfld%ipdtmpl(1)==19 .and. gfld%ipdtmpl(2)==37)then  ! ICESEV
                ! 1. Blend by Gaussian Kernel Filter
                call gaussian_smooth(0,im,jm,1,1,missing,blddata)
                do j=1,jm
                   do i=1,im
                      ij=(j-1)*im+i
                      ! 2. Keep the original matching data
                      if(usdata(i,j) == ukdata(i,j)) blddata(ij)=usdata(i,j)
                      ! 3. Re-categorize by different thresholds
                      if(abs(blddata(ij)-missing)<=EPSILON) cycle
                      if(blddata(ij) <= 0.8) then
                         blddata(ij) = 0.
                      elseif(blddata(ij) <= 1.5) then
                         blddata(ij) = 1.
                      elseif(blddata(ij) <= 2.4) then
                         blddata(ij) = 2.
                      elseif(blddata(ij) <= 3.2) then
                         blddata(ij) = 3.
                      else
                         blddata(ij) = 4.
                      end if
                      ! 4. Not greater than max, and not smaller than min of US and UK
                      blddata(ij)=min(blddata(ij),max(usdata(i,j),ukdata(i,j)))
                      blddata(ij)=max(blddata(ij),min(usdata(i,j),ukdata(i,j)))
                   end do
                end do
             end if

             call gf_free(gfld2)
             deallocate(usdata)
             deallocate(ukdata)
          else
             print*,'error code= ',ierr   
             print*, pabbrev,' not found, writting US data as blended'
             blddata = gfld%fld
             if(gfld%ibmap /= 255) then
                where(.not. gfld%bmap) blddata = missing
             end if
          end if if_ierr

          ! MIN and MAX value after first step of blending.
          ! Used to set templete 5 elements
          do ij = 1, im*jm
             if(blddata(ij) /= missing) then
                i = ij
                fldmin = blddata(ij)
                fldmax = blddata(ij)
                exit
             end if
          end do
          do ij = i, im*jm
             if(blddata(ij) /= missing) then
                if(blddata(ij) > fldmax) fldmax = blddata(ij)
                if(blddata(ij) < fldmin) fldmin = blddata(ij)
             end if
          end do

          ! ngrdpts>=ndpts when bitmap is used (for underground gridpoints)
          call write_grib2(fldmin,fldmax,gfld%ngrdpts,blddata,ifl3,listsec1,&
                           gfld%igdtnum,gfld%igdtlen,gfld%igdtmpl,&
                           gfld%ipdtnum,gfld%ipdtlen,gfld%ipdtmpl,&
                           gfld%idrtnum,gfld%idrtlen,gfld%idrtmpl)

          call gf_free(gfld)
          deallocate(blddata)
       enddo
    enddo

    print *," "
    print *, ' Total Number of Fields Found = ',itot

    call BACLOSE(ifl1, ierr)
    call BACLOSE(ifl2, ierr)
    call BACLOSE(ifl3, ierr)

  end subroutine process

! General blending of min, max or average of two values,
! when they are not missing values
  function generalblending(whichblnd,missing,exclusive,a,b)
    real :: generalblending
    character(3), intent(in) :: whichblnd
    real, intent(in) :: missing
    logical,intent(in) :: exclusive
    real, intent(in) :: a, b

    generalblending = missing
    if(a == missing .or. b == missing) then
       if(exclusive) then
          generalblending = missing
       elseif(a == missing) then
          generalblending = b
       else
          generalblending = a
       endif
    else
       if(whichblnd == 'max') then
          generalblending = max(a,b)
       elseif(whichblnd == 'min') then
          generalblending = min(a,b)
       elseif(whichblnd == 'avg') then
          generalblending = (a+b)/2.
       end if
    end if
  end function generalblending

! Abstract: smoothing a gridded field using Gaussian Kernel smoothing technique 
!
! Reference: Amy Harless et al: "A report and feature-based verification study
!     of the CAPS 2008 storm-scale ensemble forecast for severe convection
!     weather", AMS Conference 2012 
! Input: 
!       iregion: 0 - global, 1 - regional
!       im,jm: X and Y dimension of field A  
!       nbr: range of smoothing (in grids) 
!       s: sigma value of Gaussian smoothing
!       A: gridded field to be smoothed
! Output: 
!       A: Smoothed field 
! Programmer: 
!       2015-12-02: Binbin Zhou, NCEP/EMC
!       2020-01-23: Y Mao, NCEP/EMC
!
  subroutine gaussian_smooth (iregion,im,jm,nbr,s,missing,A)
    implicit none
    integer, intent(in) :: iregion ! 0 - global, 1-regional
    integer, intent(in) :: im,jm
    integer, intent(in) :: nbr, s
    real, intent(in) :: missing
    real, intent(inout) :: A(im*jm)

    real :: B(im*jm)
    real :: f1,f2,G,Gsum,AxG
    integer :: i,j,ij,ii,ip,jp,ijp,i1,i2,j1,j2

    f1=1./(3.14*s*s)
    f2=-0.5/(s*s)
    B=A

    do jp = 1,jm
       do ip = 1,im
          ijp=(jp-1)*im + ip
          i1 = ip - nbr
          i2 = ip + nbr
          j1 = jp - nbr
          j2 = jp + nbr
          if ( j1<=1 ) j1=1
          if ( j2>=jm ) j2=jm

          Gsum=0.
          AxG=0.

          do j = j1,j2
             do i = i1,i2
                ii = i
                if( i<1 ) then
                   if(iregion == 0 ) then
                      ii=i+IM
                   else
                      ii=1
                   end if
                end if
                if ( i>im ) then
                   if(iregion == 0 ) then
                      ii=i-IM
                   else
                      ii=im
                   end if
                end if
                ij = (j-1)*im + ii

                if(A(ij) /= missing) then
                   G=f1*exp(f2*((ip-i)*(ip-i)+(jp-j)*(jp-j)))
                   Gsum=Gsum+G
                   AxG=AxG+G*A(ij)
                end if
             end do
          end do

          if(Gsum>0.0) B(ijp)=AxG/Gsum

       end do
    end do

    A=B             

    return

  end subroutine gaussian_smooth


  subroutine write_grib2(min,max,npt,fld,lunout,listsec1in,&
       igdtnum,igdtlen,jgdt,ipdtnum,ipdtlen,jpdt,idrtnum,idrtlen,idrtmpl)

!******************************************************************
!  prgmmr: pondeca           org: np20         date: 2006-03-03   *
!                                                                 *
!  abstract:                                                      *
!  use steve gilbert's gribcreate, addgrid, addfield, and gribend *
!  subroutines to write data in Grib2 format                      * 
!                                                                 *
!  program history log:                                           *
!    2006-03-03  pondeca                                          *
!    2020-01-24  Y Mao (remove nflds and its dependances)         *
!                                                                 *
!  input argument list:                                           *
!                                                                 *
! 1. min: min value of array fld(npt)                             *
!                                                                 *
! 2. max: max value of array fld(npt)                             *
!                                                                 *
! 3. npt: size of data array to be written                        *
!                                                                 *
! 4. fld: data array to be written                                *
!                                                                 *
! 5. lunout: file handler/unit of output Grib2 file               *
!                                                                 *
! 6. listsec1in: array of reference time (year, month, day, hour, *
!    minutes and seconds)                                         *
!                                                                 *
! 7. igdtnum: Grid Definition Template Number (Code Table 3.0)    *
!                                                                 *
! 8. igdtlen: length of grid template array                       *
!                                                                 *
! 9. jgdt: array values of Grid Definition Template              *
!                                                                 *
! 10. ipdtnum: Product Definition Template Number (Code Table 4.0)*
!                                                                 *
! 11. ipdtlen: length of product template array                   *
!                                                                 *
! 12. jpdt: array values of Product Definition Template           *
!                                                                 *
! attributes:                                                     *
!   language: f90                                                 *
!******************************************************************
    implicit none

    real, intent(in) :: min,max
    integer, intent(in) :: npt
    real(4), intent(in) :: fld(npt)
    integer, intent(in) :: lunout
    integer, intent(in) :: listsec1in(:)

    integer, intent(in) :: igdtnum
    integer, intent(in) :: igdtlen
    integer, intent(in) :: jgdt(igdtlen)

    integer, intent(in) :: ipdtnum
    integer, intent(in) :: ipdtlen
    integer, intent(in) :: jpdt(ipdtlen)

    integer, intent(in) :: idrtnum
    integer, intent(in) :: idrtlen
    integer, intent(in) :: idrtmpl(idrtlen)

    integer(4), parameter :: idefnum=1

    integer(4) :: max_bytes

    integer(4) :: listsec0(2),listsec1(13)
    integer(4) :: ierr,i,j,ij
    integer(4) :: lengrib

    integer(4) :: igds(5)
    integer(4) :: igdstmpl(igdtlen) 
    integer(4) :: ideflist(idefnum)     
    integer(4) :: ipdstmpl(ipdtlen)
    integer(4) :: numcoord

    integer(4) :: ibmap
    logical*1 :: bmap(npt)

    character*1,allocatable :: cgrib(:)
 
    real(4) :: coordlist

    max_bytes = npt*4
    allocate(cgrib(max_bytes))

!==>initialize new GRIB2 message and pack

! GRIB2 sections 0 (Indicator Section) and 1 (Identification Section)
    listsec0(1)=0 ! Discipline-GRIB Master Table Number (see Code Table 0.0)
    listsec0(2)=2 ! GRIB Edition Number (currently 2)

    listsec1(:) = listsec1in(:)
    listsec1(1)=7 ! Id of orginating centre (Common Code Table C-1)
    listsec1(2)=4 !"EMC"! Id of orginating sub-centre (local table)/Table C of ON388
    ! Yali Mao, GFS master table is 25 for WAFS at 0.25 deg (US unblended data is already set to 25)
!    listsec1(3)=25    ! GRIB Master Tables Version Number (Code Table 1.0)
    listsec1(4)=1    ! per Brent! GRIB Local Tables Version Number (Code Table 1.1)
    listsec1(5)=1    ! Significance of Reference Time (Code Table 1.2)
!   listsec1(6)      ! Reference Time - Year (4 digits)
!   listsec1(7)      ! Reference Time - Month
!   listsec1(8)      ! Reference Time - Day
!   listsec1(9)      ! Reference Time - Hour
    listsec1(10) = 0 ! Reference Time - Minute
    listsec1(11) = 0 ! Reference Time - Second
    listsec1(12) = 0 ! Production status of data (Code Table 1.3)
    listsec1(13) = 1 ! Type of processed data (Code Table 1.4)
                     ! 0 for analysis products and 1 for forecast products

    call gribcreate(cgrib,max_bytes,listsec0,listsec1,ierr)
    print*,'gribcreate status=',ierr

!==> Pack up Grid Definition Section (Section 3) add to GRIB2 message.

    call apply_template_300(jgdt,igdstmpl) 

    igds(1)=0   !Source of grid definition (see Code Table 3.0)
    igds(2)=npt !Number of grid points in the defined grid.
    igds(3)=0   !Number of octets needed for each additional grid points definition
    igds(4)=0   !Interpretation of list for optional points definition (Code Table 3.11)
    igds(5)=igdtnum !Grid Definition Template Number (Code Table 3.1)

    ideflist=0  !Used if igds(3) /= 0. Dummy array otherwise

    call addgrid(cgrib,max_bytes,igds,igdstmpl,igdtlen,ideflist,idefnum,ierr)
    print*,'addgrid status=',ierr

!==> pack up sections 4 through 7 for a given field and add them to a GRIB2 message.  
! They are Product Definition Section, Data Representation Section, Bit-Map Section 
! and Data Section, respectively.

    call apply_template_40(jpdt,ipdstmpl)
    print*,'product template in new Grib file= ',ipdstmpl

    ! Use US unblended template 5 information (5.40)
!!!    idrtnum=40    !Data Representation Template Number ( see Code Table 5.0 )
!!!    call apply_template_50(min,max,jpdt(1),jpdt(2),idrtmpl)

    numcoord=0
    coordlist=0. !needed for hybrid vertical coordinate

    ibmap=255 ! Bitmap indicator ( see Code Table 6.0 ), WAFS Blended products do not use bit-map

    print *, "npt=",npt
    print *, "ipdtnum=",ipdtnum,ipdtlen,ipdstmpl
    print *, "coordlist=",coordlist,numcoord
    print *, "idrtnum=",idrtnum,idrtlen,idrtmpl
    call addfield(cgrib,max_bytes,ipdtnum,ipdstmpl,ipdtlen, &
                  coordlist,numcoord,idrtnum,idrtmpl, &
                  idrtlen,fld,npt,ibmap,bmap,ierr)
    print*,'addfield status=',ierr

!==> finalize  GRIB message after all grids
! and fields have been added.  It adds the End Section ( "7777" )

    call gribend(cgrib,max_bytes,lengrib,ierr)
    print*,'gribend status=',ierr
    print*,'length of the final GRIB2 message in octets =',lengrib
    call wryte(lunout, lengrib, cgrib)

    deallocate(cgrib)
    return
  end subroutine write_grib2

!===========================================================================
  subroutine apply_template_300(jgdt,ifield3) 

    implicit none

    integer,intent(in)::jgdt(:)
    integer(4),intent(out) :: ifield3(:)

    ifield3 = jgdt

    ifield3(11) = 0
 
    return
  end subroutine apply_template_300

!===========================================================================
  subroutine apply_template_40(jpdt,ifield4)

    implicit none

    integer,intent(in) :: jpdt(:)
    integer(4),intent(out) :: ifield4(:)

    ifield4 = jpdt
   
!==> ifield4(1):parameter category (see Code Table 4.1)
!==> ifield4(2):parameter number (see Code Table 4.2)

!==> ifield4(3):type of generating process (see Code Table 4.3)
!    0 - analysis
!    2 - forecast
!    7 - analysis error

!==>ifield4(4):background generating process identifier 
!              (defined by originating Center)
    ifield4(4) = 0 !hasn't been defined yet 

!==>ifield4(5):analysis or forecast generating process identifier 
!              (defined by originating Center)
    ifield4(5) = 96

!==>ifield4(6):hours of observational data cutoff after reference time 
!==>ifield4(7):minutes of observational data cutoff after reference time 
    ifield4(6) = 0   ! per steve
    ifield4(7) = 0   

!==>ifield4(8):indicator of unit of time range (see Code Table 4.4) 
    ifield4(8) = 1   

!==>ifield4(9):forecast time in units defined by ifield4(8) 

!==>ifield4(10):type of first fixed surface (see Code Table 4.5)
!==>ifield4(11):scale factor of first fixed surface
    ifield4(11) = 0 !Because not saving any precision
!==>ifield4(12):scaled value of first fixed surface

!==>ifield4(13):type of second fixed surface(See Code Table 4.5)
!==>ifield4(14):scale factor of second fixed surface
!==>ifield4(15):scaled value of second fixed surface
    ifield4(13) = 255
    ifield4(14) = 0
    ifield4(15) = 0

    if(size(jpdt)>=16) then
!==> ifield4(16):Statistical process used within the spatial area (see Code Table 4.10)

       ifield4(17) = 3 ! Type of spatial processing
       ifield4(18) = 1 ! Number of data points used in spatial processing
    end if

    return
  end subroutine apply_template_40

!===========================================================================
  subroutine apply_template_50(min,max,ncat,nparm,ifield5) 

    implicit none

    real,intent(in) :: min,max
    integer,intent(in) :: ncat,nparm
    integer(4),intent(out) :: ifield5(:)

    ! reference value(R) (IEEE 32-bit floating-point value)
    ifield5(1)=0 ! Any value. Will be overwritten

    ifield5(2)=0! binary scale factor (E)

    ! decimal scale factor (D)
    if (ncat==19 .and. nparm==37) then ! ICESEV
       ifield5(3) = 0
    else if (ncat==19 .and. nparm==30) then ! EDR
       ifield5(3) = 2
    else if(ncat==3 .and. nparm==3) then ! CB base/top
       ifield5(3) = 0
    else if (ncat==6 .and. nparm==25) then ! Cb ext
       ifield5(3) = 1
    else
       ifield5(3) = 2
    endif

    ! number of bits used for each packed value for simple packing
    ! or for each group reference value for complex packing or
    ! spatial differencing
    ifield5(4) = 0 ! Must reset to 0

    ifield5(5) = 0 ! type of original field values (See Code Table 5.1)

    ! Rarely happens for WAFS data, just in case
    if(min == max) then
       ifield5(2)=0
       ifield5(3)=0
    end if

    return
  end subroutine apply_template_50

!===========================================================================
!$$$  SUBPROGRAM DOCUMENTATION BLOCK 
!                .      .    .                                       . 
! SUBPROGRAM:    GETLUN      GET UNIQUE LOGICAL UNIT NUMBERS
!   PRGMMR: SMITH, TRACY     ORG: FSL/PROFS  DATE: 90-06-15 
! 
! ABSTRACT: THIS PROGRAM GETS UNIQUE LOGICAL UNIT NUMBERS FOR OPFILE
!   OR RETURNS THEM TO THE POOL FOR CLFILE.
! 
! PROGRAM HISTORY LOG: 
! FORTRAN 90 VERSION IS GETLUN90:  PONDECA,      DATE: 2006-03-08
! 
! USAGE:    CALL GETLUN(LUN,OPTN) 
!   INPUT ARGUMENT LIST: 
!     LUN      - INTEGER  LOGICAL UNIT NUMBER
!     OPTN     - INTEGER  CNCT=1, DSCT=2.
!                IF CONNECTING A FILE(CNCT) SET THE NUMBER TO
!                NEGATIVE SO IT WON'T BE USED UNTIL AFTER
!                DSCT SETS IT POSITIVE.
! 
!   OUTPUT ARGUMENT LIST:   
!     LUN      - INTEGER  LOGICAL UNIT NUMBER
! 
! REMARKS: 
! 
! ATTRIBUTES: 
!   LANGUAGE: FORTRAN-90
!   MACHINE:  NAS-9000 
!$$$ 

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

end module blending

program main

  use blending

  implicit none

  character(60) :: gfile1,gfile2,gfile3

  INTEGER :: NARG

  call start()

! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  GET ARGUMENTS
  NARG=IARGC()
  IF(NARG /= 3) THEN
     CALL ERRMSG('blending:  Incorrect usage')
     CALL ERRMSG('Usage: wafs_blending_0p25 grib2file1 grib2file2 grib2file3')
     CALL ERREXIT(2)
  ENDIF

  CALL GETARG(1,gfile1)
  CALL GETARG(2,gfile2)
  CALL GETARG(3,gfile3)

  call process(trim(gfile1),trim(gfile2),trim(gfile3))

end program main


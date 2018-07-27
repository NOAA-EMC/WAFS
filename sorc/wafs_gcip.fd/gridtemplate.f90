!------------------------------------------------------------------------------
!
! MODULE: GridTemplate
!
! DESCRIPTION:
!> Provide subroutines to calculate nearby gridpoints for station observations
!> Must use the following steps to achieve the result:
!>   1. call initNearbyGridPoints
!>   2. call getNearbyGridPoints
!>   3. call doneNearbyGridPoints
!> It also provides subroutine freeNearbyGridPoints to free the memory allocated
!> for a nearby_gridpoint_t object
!>
!> Other independant subroutines:
!>   zoominGDS
!>   convertProjection
!
! REVISION HISTORY:
! September 2011
! January 2014 - modified
!
!------------------------------------------------------------------------------

module GridTemplate
  use Kinds
  use GDSWZD_MOD

  private
  public nearby_gridpoint_t
  ! The required 3 steps for nearby gridpoints
  public initNearbyGridPoints, getNearbyGridPoints, doneNearbyGridPoints
  ! Help to release the memory of the gridpoints
  public freeNearbyGridPoints
  !
  ! Other auxiliary subroutines for Radar and Satellite
  public zoominGDS, convertProjection

  ! grid points for METAR, SHIPs, PIREPs and LIGHTNING
  ! Data structure: stack
  !               : %next==NULL means empty, the first element is useless.
  type :: nearby_gridpoint_t
    integer :: i
    integer :: j
    real :: distance
    type(nearby_gridpoint_t), pointer :: next
  end type nearby_gridpoint_t

  real, parameter :: RERTH = 6371.2040 ! in km

  real    :: radius
  integer :: kgds(200)
  integer :: nx, ny, projType
  !
  real, allocatable :: lat(:), lon(:) ! for GFS Guassian, in degree
  real :: dx, dy                      ! for RAP/NAM Lambert Conformal, in km

  real, allocatable :: alat(:) ! expanded version of lat

contains

  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> Assign/calculate member variables from input KGDS and influencing radius. 
  !> Meanwhile, allocate memory of lat(:) lon(:) if it's a GFS model
  !
  !> @param[in] kgds0     - model grid information
  !> @param[in] radius0   - radius within which an observation influences
  !----------------------------------------------------------------------------

  subroutine  initNearbyGridPoints(kgds0, radius0)
    implicit none

    integer, intent(in) :: kgds0(200)
    real,    intent(in) :: radius0

    real, allocatable :: slat(:), mesh(:) ! For GFS Guassian
    integer :: i

    kgds(:) = kgds0(:)
    radius = radius0

    nx = kgds(2)
    ny = kgds(3)
    projType = kgds(1)

    ! LAMBERT CONFORMAL
    if(projType == 3) then
       dx = kgds(8)/1000. ! in km
       dy = kgds(9)/1000. ! in km
    else if(projType == 4 .or. projType == 0) then
    ! if GAUSSIAN CYLINDRICAL or EQUIDISTANT CYLINDRICAL
       allocate(mesh(ny))
       allocate( lat(ny))
       allocate( lon(nx))
       ! caculate lat lon
       lon(:) = (/ ((360./nx) * (i-1), i = 1, nx) /) ! in degree
       call SPLAT(projType, ny, lat(:), mesh(:))     ! sine of latitude
       lat(:) = asin(lat(:)) * R2D                   ! in degree
       ! deallocate mesh
       deallocate(mesh)
    end if

    allocate(alat(0:ny+1))
    alat(1:ny) = lat(1:ny)
    alat(0)=90.0
    alat(ny+1)=-90.0

    return
  end subroutine initNearbyGridPoints

  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> Get all grid points (i,j)s within the radius from the station (lat0, lon0)
  !> for GFS / (x0, y0) for RAP/NAM
  !> These gridpoints are influenced by the station locations.
  !
  !> @param[in]  lat0   - latitude
  !> @param[in]  lon0   - logitude
  !> @param[out] points - nearby gridpoint stack
  !----------------------------------------------------------------------------

  subroutine getNearbyGridPoints(lat0, lon0, points)
    implicit none
    real,    intent(inout)  :: lat0, lon0 ! (lat, lon) of a station
    ! gridpoints influenced by the station
    type(nearby_gridpoint_t), target, intent(out) :: points

    ! To call GDSWZD()
    integer :: iopt, npts, ret
    ! rlon [-360, 360], rlat [-90, 90]
    real    :: fill,x0, y0,crot0,srot0
    real, dimension(1) :: aX,aY,aLat,aLon,aCrot,aSrot

    ! To include unique gridpoints in all quadrants
    type :: ij_direction_t
      integer :: start
      integer :: end
      integer :: step
    end type ij_direction_t
    type(ij_direction_t) :: idirection(2), jdirection(2)

    integer :: i, j, ii, jj, idir, jdir
    real    :: distance

    nullify(points%next)

    ! To avoid duplicate gridpoints at high lat of GFS, which are closed to each other
    idirection(1) = ij_direction_t( 0,     nx/2,  1)
    idirection(2) = ij_direction_t(-1,-(nx-1)/2, -1)
    jdirection(1) = ij_direction_t( 0, ny,  1)
    jdirection(2) = ij_direction_t(-1,-ny, -1)

    npts = 1      ! 1 point to be calculated
    aLat(1)=lat0
    aLon(1)=lon0
    fill = -1.    ! for invalid value
    iopt = -1     ! COMPUTE GRID COORDS OF SELECTED EARTH COORDS
    !iopt = 1     ! COMPUTE EARTH COORDS OF SELECTED GRID COORDS
    !iopt = 0     ! COMPUTE EARTH COORDS OF ALL THE GRID POINTS

    ! call GDSWZD modified version to avoid calling SPLAT, 
    ! scalar value argument is used.
    if (kgds(1) == 4) then
       call m_gdswzd04(kgds,iopt,npts,fill,x0,y0,lon0,lat0,ret,crot0,srot0)
    else
!       call GDSWZD(kgds,iopt,npts,fill,x0,y0,lon0,lat0,ret,crot,srot)
       call GDSWZD(kgds,iopt,npts,fill,aX,aY,aLon,aLat,ret,aCrot,aSrot)
       x0 = aX(1)
       y0 = aY(1)
    endif

    ! with radious==0.0, only add one grid point nearest to (lat0, lon0)
    if( radius < 0.0001) then
      i = nint(x0)
      j = nint(y0)
      if( (i >= 1 .and. i <= nx) .and. (j >= 1 .and. j <= ny)) then
        call m_addNearbyGridPt(i, j, radius, points)
      end if
      return
    end if

    ! LAMBERT CONFORMAL
    if_projType: if(projType == 3) then
      if_lc_y0: if( y0 >= 0.) then ! discard stations out of model's domain
        ! control quadrants by x/y axes direction
        do jdir = 1, 2
        do idir = 1, 2
          ! control searching range from nearest to fartherest, stop promptly
          do jj = jdirection(jdir)%start, jdirection(jdir)%end, jdirection(jdir)%step 
          do ii = idirection(idir)%start, idirection(idir)%end, idirection(idir)%step
            ! For NAM/RAP Lambert, distance between gridpoints are quadrantly same
            distance = sqrt(((ii-x0)*dx)**2 + ((jj-y0)*dy)**2)
            if_distance_lc: if( distance <= radius) then
              i = nint(x0 + ii)
              j = nint(y0 + jj)
              if( (i >= 1 .and. i <= nx) .and. (j >= 1 .and. j <= ny)) then
!write(*,*) x0, y0, ii, jj, distance
                 call m_addNearbyGridPt(i, j, distance, points)
              endif
            else
              exit
            endif if_distance_lc
          enddo
          enddo
        enddo
        enddo
      endif if_lc_y0
    ! GAUSSIAN CYLINDRICAL / EQUIDISTANT CYLINDRICAL
    elseif(projType == 4 .or. projType == 0) then
      if_gc_y0: if( y0 >= 0.) then ! I don't see the reason for GFS, but to be safe
       ! control quadrants by x/y axes direction
        do jdir = 1, 2
        do idir = 1, 2
          ! control searching range from nearest to fartherest, stop promptly
          do jj = jdirection(jdir)%start, jdirection(jdir)%end, jdirection(jdir)%step
            j = nint(y0 + jj)
            if(j < 1 .or. j > ny) exit
            do ii = idirection(idir)%start, idirection(idir)%end, idirection(idir)%step
              i = nint(x0 + ii)
              if(i < 1)  i = i + nx
              if(i > nx) i = i - nx 
              ! For GFS Guassian, distance between grid points are south-north differently
              distance = m_distanceLatLon(lat0, lon0, lat(j), lon(i))
              if_distance_gc: if( distance <= radius) then
!write(*,*) x0, y0, ii, jj, distance
                 call m_addNearbyGridPt(i, j, distance, points)
              else
                exit
              endif if_distance_gc
            enddo
          enddo
        enddo
        enddo
      endif if_gc_y0
    else
      write(*,*) "Projection kgpds(1)=", projType, " is not supported yet"
      return
    endif if_projType

    return
  end subroutine getNearbyGridPoints


  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> Mimic gdswiz04.f from IPLIB, to skip SPLAT call for each observation.
  !> This subroutine only calcuate scalar value, not an array
  !> This subroutine depends on lat(:) initialized by initNearbyGridPoints()
  !
  !----------------------------------------------------------------------------
  subroutine m_gdswzd04(kgds,iopt,npts,fill,xpts,ypts,rlon,rlat,nret,crot,srot)
    implicit none

    integer, intent(in) :: kgds(200)
    integer, intent(in) :: iopt, npts
    real, intent(in) :: fill
    real :: xpts,ypts! input if iopt>=0; output if iopt<0
    real :: rlon,rlat! output if iopt>=0; input if iopt<0
    integer, intent(out) :: nret
    real, intent(out) :: crot,srot

    integer :: im,jm,jg,iscan,jscan,nscan
    real :: rlat1,rlat2,rlon1,rlon2,dlon
    integer :: jh,j1,j2
    real :: hi,xmin,xmax,ymin,ymax

    integer :: j,n,ja
    real :: wb,rlata,rlatb,yptsa,yptsb

    crot=1
    srot=0

    nret=-1

    if(npts > 1) then
       write(*,*) "m_gdswzd04() only calculates scalar value, not an array"

       if(iopt>=0) then
          rlon=fill
          rlat=fill
       endif
       if(iopt<=0) then
          xpts=fill
          ypts=fill
       endif

       return
    endif
    

    if(kgds(1) == 4) then
       im=kgds(2)
       jm=kgds(3)
       rlat1=kgds(4)*1.e-3
       rlon1=kgds(5)*1.e-3
       rlat2=kgds(7)*1.e-3
       rlon2=kgds(8)*1.e-3
       jg=kgds(10)*2
       iscan=mod(kgds(11)/128,2)
       jscan=mod(kgds(11)/64,2)
       nscan=mod(kgds(11)/32,2)
       hi=(-1.)**iscan
       jh=(-1)**jscan
       dlon=hi*(mod(hi*(rlon2-rlon1)-1+3600,360.)+1)/(im-1)
       j1=1
       do while(j1<jg .and. rlat1<(alat(j1)+alat(j1+1))/2)
          j1=j1+1
       enddo
       j2=j1+jh*(jm-1)
       xmin=0
       xmax=im+1
       if(im == nint(360./abs(dlon))) xmax=im+2
       ymin=0.5
       ymax=jm+0.5

       nret=0

       ! translate grid coordinates to earth coordinates
       if(iopt == 0 .or. iopt == 1) then
          if(xpts >= xmin .and. xpts <= xmax.and. &
             ypts >= ymin .and. ypts <= ymax) then
             rlon=mod(rlon1+dlon*(xpts-1)+3600,360.)
             j=min(int(ypts),jm)
             rlata=alat(j1+jh*(j-1))
             rlatb=alat(j1+jh*j)
             wb=ypts-j
             rlat=rlata+wb*(rlatb-rlata)
             nret=nret+1
          else
             rlon=fill
             rlat=fill
          endif

       ! translate earth coordinates to grid coordinates
       elseif(iopt == -1) then
          xpts=fill
          ypts=fill
          if(abs(rlon)<=360 .and. abs(rlat) <= 90) then
             xpts=1+hi*mod(hi*(rlon-rlon1)+3600,360.)/dlon
             ja=min(int((jg+1)/180.*(90-rlat)),jg)
             if(rlat>alat(ja)) ja=max(ja-2,0)
             if(rlat<alat(ja+1)) ja=min(ja+2,jg)
             if(rlat>alat(ja)) ja=ja-1
             if(rlat<alat(ja+1)) ja=ja+1
             yptsa=1+jh*(ja-j1)
             yptsb=1+jh*(ja+1-j1)
             wb=(alat(ja)-rlat)/(alat(ja)-alat(ja+1))
             ypts=yptsa+wb*(yptsb-yptsa)
             if(xpts>=xmin.and.xpts<=xmax .and. &
                ypts>=ymin.and.ypts<=ymax) then
                nret=nret+1
             else
                xpts=fill
                ypts=fill
             endif
          endif

       endif

    ! projection unrecognized
    else
       if(iopt>=0) then
          rlon=fill
          rlat=fill
       endif
       if(iopt<=0) then
          xpts=fill
          ypts=fill
       endif
    endif

    return

  end subroutine m_gdswzd04

  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> Add a grid point (i,j) with distance to nearby gridpoint stack
  !
  !> @param[in]  i        - coordinate i of a gridpoint
  !> @param[in]  j        - coordinate j of a gridpoint 
  !> @param[in]  distance - distance between (lat0, lon0) and gridpoint (i,j)
  !> @param[out] points   - nearby gridpoint stack
  !----------------------------------------------------------------------------
  
  subroutine m_addNearbyGridPt(i, j, distance, points)
    integer, intent(in) :: i, j
    real,    intent(in) :: distance
    type(nearby_gridpoint_t), target, intent(inout) :: points

    type(nearby_gridpoint_t), pointer :: pointIterator

    allocate(pointIterator)

    pointIterator%i = i
    pointIterator%j = j
    pointIterator%distance = distance

    pointIterator%next => points%next
    points%next => pointIterator

    return
  end subroutine m_addNearbyGridPt

  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> calculate the distance between two earth location of (lat, lon)
  !----------------------------------------------------------------------------

  real function m_distanceLatLon(lat01, lon01, lat02, lon02)
    real, intent(in) :: lat01, lon01, lat02, lon02 ! in degree

    real :: lat1, lon1, lat2, lon2
    real :: dlat, dlon, a, c

    ! Calculate the real distance
    ! http://www.movable-type.co.uk/scripts/latlong.html
    ! a = [sin(^[$B&$^[(Blat/2)]**2 +
    ! cos(lat1).cos(lat2).[sin(^[$B&$^[(Blong/2)]**2
    ! c = 2.atan2(^[$B"e^[(Ba, ^[$B"e^[(B(1^[$B!]^[(Ba))
    ! d = R.c

    lat1 = lat01 * D2R
    lon1 = lon01 * D2R
    lat2 = lat02 * D2R
    lon2 = lon02 * D2R

    dlat = lat1-lat2
    dlon = lon1-lon2
    a = sin(dlat/2.) ** 2.0 + cos(lat1)*cos(lat2) * sin(dlon/2.)*sin(dlon/2.)
    c = 2. * atan2(sqrt(a), sqrt(1-a))
    m_distanceLatLon = RERTH * c
  end function m_distanceLatLon

  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> Free the memory of nearby gridpoint stack
  !----------------------------------------------------------------------------

  subroutine freeNearbyGridPoints(stack)
    type(nearby_gridpoint_t), target, intent(inout) :: stack

    type(nearby_gridpoint_t), pointer :: iterator

    iterator => stack%next
    do while(associated(iterator))
      iterator => iterator%next
      deallocate(stack%next, stat=iret)
      stack%next => iterator
    end do

    return
  end subroutine freeNearbyGridPoints

  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> Do clean up after getting all nearby gridpoints
  !----------------------------------------------------------------------------
 
  subroutine doneNearbyGridPoints()
    if(allocated(lat)) deallocate(lat)
    if(allocated(lon)) deallocate(lon)
    if(allocated(alat)) deallocate(alat)
  end subroutine doneNearbyGridPoints


  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> Given a kgds and nfiner, get a zoomin gds
  !----------------------------------------------------------------------------
  subroutine zoominGDS(kgds, nfiner, tgds)
    integer, intent(in) :: kgds(:)
    integer, intent(in) :: nfiner
    integer, intent(inout) :: tgds(:)

    tgds(:) = kgds(:)
    if(tgds(1) == 0) then
       ! EQUIDISTANT CYLINDRICAL
       tgds(2) = kgds(2) * nfiner
       tgds(3) = kgds(3) * nfiner
       ! 4 5  7, the same as kgds
       tgds(9) =  real(kgds(9)) / real(nfiner)! won't be used by GDSWZD04
       tgds(10)=  real(kgds(10))/ real(nfiner)! won't be used by GDSWZD04
       tgds(8) = 360*1000-tgds(9)
    elseif(tgds(1) == 4) then
       ! GAUSSIAN CYLINDRICAL
       tgds(2) = kgds(2) * nfiner
       tgds(3) = kgds(3) * nfiner
       tgds(4) = m_getGaussianLat0(tgds(3), tgds(1))*1000.0
       tgds(7) = -tgds(4)
       tgds(8) = int(360. * (tgds(2) - 1)/tgds(2) * 1000)
       tgds(9) = nint(360./tgds(2) * 1000.) ! won't be used by GDSWZD04
       tgds(10) = kgds(10) * nfiner
    else if(tgds(1) == 3) then
       ! Lambert Conformal
       tgds(2) = kgds(2) * nfiner
       tgds(3) = kgds(3) * nfiner
    end if

    return

  end subroutine zoominGDS

  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> get the latitude of the northernmost grid points on Gaussian grid
  !----------------------------------------------------------------------------

  function m_getGaussianLat0(ny, grid)
    real :: m_getGaussianLat0
    integer, intent(in) :: ny
    integer, intent(in) :: grid

    real :: mesh(ny), lat(ny)

    call splat(grid, ny, lat, mesh) ! grid=4: Gaussian grid
    lat(:) = asin(lat(:)) * R2D
    m_getGaussianLat0 = lat(1)
  end function m_getGaussianLat0


  !----------------------------------------------------------------------------
  ! DESCRIPTION:
  !> convert data from a source projection (sgds) to a target projection(tgds)
  !
  !> @param[in]  sgds  - source projection (provided by GDS grid information)
  !> @param[in]  sdata - source data
  !> @param[out] tgds  - target projection (provided by GDS grid information)
  !> @param[out] tdata - converted data
  !> @param[out] iret  - status; -1 if failure
  !
  !----------------------------------------------------------------------------
  subroutine convertProjection(sgds, sdata, tgds, tdata, iret)
    implicit none
    integer, intent(in) :: sgds(:)
    real, intent(in)    :: sdata(:,:)
    integer, intent(in) :: tgds(:)
    real, intent(inout) :: tdata(:,:)
    integer, intent(out):: iret

    integer :: nx, ny
    integer :: i, j

    real, allocatable :: lat(:,:), lon(:,:), x(:,:), y(:,:)
    real :: lon0, lat0, x0, y0, crot0, srot0
    integer :: i0, j0

    ! other variables for GDSWZD
    integer :: iopt, npts
    real, allocatable :: crot(:,:), srot(:,:)
    real :: fill

    fill = MISSING

    nx = tgds(2)
    ny = tgds(3)


    ! get earth coordinate (lat, lon) for each grid point of the target tgds
    allocate(x(nx, ny))
    allocate(y(nx, ny))
    allocate(lat(nx, ny))
    allocate(lon(nx, ny))
    allocate(crot(nx, ny))
    allocate(srot(nx, ny))
    iopt = 0       ! COMPUTE EARTH COORDS OF ALL THE GRID POINTS
    npts = nx * ny
    call GDSWZD(tgds,iopt,npts,fill,x,y,lon,lat,iret,crot,srot)
    write(*,*) "convertProjection: get target (lat,lon), numbers:", iret

    iopt = -1 ! COMPUTE GRID COORDS OF SELECTED EARTH COORDS
    
    call GDSWZD(sgds,iopt,npts,fill,x,y,lon,lat,iret,crot,srot)
    write(*,*) "convertProjection: convert target (lat,lon) to source (x,y), numbers:", iret

    tdata(:,:) = MISSING
    do j = 1, ny
       do i = 1, nx
          i0 = nint(x(i,j))
          j0 = nint(y(i,j))
          if( (i0 >= 1 .and. i0 <= sgds(2)) .and. (j0 >= 1 .and. j0 <= sgds(3))) then
             tdata(i,j) = sdata(i0,j0)
          end if
       end do
    end do
          
    deallocate(x)
    deallocate(y)
    deallocate(crot)
    deallocate(srot)

    deallocate(lat)
    deallocate(lon)

    iret = 0
    return
  end subroutine convertProjection

end module GridTemplate

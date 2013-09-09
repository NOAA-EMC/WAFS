! waf_main.f90
! contains subroutines to calculate icing
! George Trojan, SAIC/EMC/NCEP, January 2007
! Last update: 11/05/09

module waf_main

use fuzzy
use getoptions
use kinds
use physcons
use waf_config
use waf_glob
use waf_phys

implicit none

public

! default values for testing
character(len=*), parameter :: def_cfg_file = 'waf.cfg'
character(len=*), parameter :: def_output_file = 'waf.grib'

! PDS parameters in the input GRIB file (kpds5, kpds6, kpds7 unused)
type(pds_t), parameter :: &
    pds_sfc_pres = pds_t(1, 1), &
    pds_hgt = pds_t(7, 100), &
    pds_temp = pds_t(11, 100), &
    pds_u_wnd = pds_t(33, 100), &
    pds_v_wnd = pds_t(34, 100), &
    pds_vvel = pds_t(39, 100), &
    pds_rh = pds_t(52, 100), &
    pds_cld_w = pds_t(153, 100), &
    pds_conv_pres_bot = pds_t(1, 242), &
    pds_conv_pres_top = pds_t(1, 243), &
    pds_tot_cld_cover = pds_t(71, 200), &
    pds_conv_pcp_rate = pds_t(214, 1)

contains
!----------------------------------------------------------------------------
subroutine usage()
! prints proper usage
    character(len=256) :: progname

    call getarg(0, progname)
    print *, 'Usage: ', trim(progname), &
        ' [-c config-file -o output-file] -i input-file product ...'
    print *, 'The defaults are:'
    print *, 'config-file: ', def_cfg_file
    print *, 'output-file: ', def_output_file
    print *, 'Products:'
    print *, '\t1: icng - Icing potential'
    print *, '\t2: cat - Clear Area Turbulence'
    print *, '\t3: tcld - In-cloud turbulence'
    print *, '\t4: cb - Cumulonimbus'
end subroutine usage

!----------------------------------------------------------------------------
subroutine prog_args(cfg_file, input_file, output_file, products, iret)
! parses program arguments
    character(len=*), intent(out) :: cfg_file ! configuration file
    character(len=*), intent(out) :: input_file ! input data file (from npost)
    character(len=*), intent(out) :: output_file ! output data file (GRIB)
    type(product_t), intent(out) :: products ! requested products
    integer, intent(out) :: iret ! return code, 0 on success

    character :: okey
    character(len=*), parameter :: options = 'c:i:o:'

    ! set defaults
    cfg_file = def_cfg_file
    output_file = def_output_file
    input_file = ' '
    products%do_cat = .false.
    products%do_icng = .false.
    products%do_cb = .false.
    products%do_tcld = .false.
    ! process command arguments
    iret = 0
    do
        okey = getopt(options)
        select case (okey)
        case ('>')
            exit
        case ('c')
            cfg_file = optarg
        case ('i')
            input_file = optarg
        case ('o')
            output_file = optarg
        case ('.')
            select case(optarg)
            case ('cb')
                products%do_cb = .true.
            case ('cat')
                products%do_cat = .true.
            case ('tcld')
                products%do_tcld = .true.
            case ('icng')
                products%do_icng = .true.
            case default
                iret = 1
                exit
            end select
        case default
            iret = 1
            exit
        end select
    end do
    if (iret /= 0 .or. input_file == ' ' .or. .not. products%do_cb &
        .and. .not. products%do_cat .and. .not. products%do_tcld &
        .and. .not. products%do_icng) then
        iret = 1
        call usage()
    end if
end subroutine prog_args

!----------------------------------------------------------------------------
subroutine put_waf_field(gparms, pds7, def_pds, def_gds, nx, ny, array, iret)
! writes calculated values for one field at all pressure levels
    type(gparms_t), intent(in) :: gparms ! field-specific pds parameters
    integer, intent(in) :: pds7 ! usually pressure level
    integer, dimension(:), intent(in) :: def_pds, def_gds ! PDS and GDS 
        ! values from model data file
    integer, intent(in) :: nx, ny ! grid dimensions
    real(kind=r_kind), dimension(nx,ny) :: array ! data to be written
    integer, intent(out) :: iret ! return code from putgb()

    integer :: npoints
    integer, dimension(glob_w3_size) :: pds, gds ! arrays holding PDS 
        ! and GDS values written to output file
    logical(kind=1), dimension(nx,ny) :: mask
    character(len=*), parameter :: myself = 'put_waf_field(): '

    npoints = nx * ny
    pds = def_pds
    gds = def_gds
    if (gparms%bitmap) pds(4) = ior(pds(4), 64)
    pds(5) = gparms%pds5   ! field number (GRIB table 2)
    pds(6) = gparms%pds6   ! field level type (GRIB table 3)
    pds(7) = pds7
    pds(19) = glob_avn_table
    pds(22) = gparms%pds22 ! precision
    if (gparms%bitmap) then
        mask = array /= gparms%msng
    else
        mask = .false.
    end if
    call putgb(glob_lu_out, npoints, pds, gds, mask, array, iret)
    if (iret /= 0) then
        print *, myself, 'failed to store field ', pds(5:7)
    end if
end subroutine put_waf_field

!----------------------------------------------------------------------------
subroutine get_grib_parms(pds_data, gds_data, iret)
! returns PDS and GDS section of the first GRIB field
! we assume here that the input grids are the same for all fields
    integer, dimension(:), intent(out) :: pds_data, gds_data ! retrieved PDS 
                                                             ! and GDS data
    integer, intent(out) :: iret ! return code, from getgbh()
 
    integer :: kg, kf, k
    integer, dimension(glob_w3_size), parameter :: pds_mask = -1, &
        gds_mask = -1   ! search mask, -1 is wild card
    character(len=*), parameter :: myself = 'get_grib_parms(): '

    pds_data = 0
    gds_data = 0
    ! getgbh() is in libw3
    call getgbh(glob_lu_in, 0, -1, pds_mask, gds_mask, kg, kf, k, pds_data, &
        gds_data, iret)
    if (iret /= 0) print *, myself, 'getgbh() failed, iret = ', iret
end subroutine get_grib_parms

!----------------------------------------------------------------------------
subroutine get_field(pds_def, pres_level, nx, ny, data_array, iret)
! retrieves one field specified by index field_ix at pressure level p
    type(pds_t), intent(in) :: pds_def ! field and level type
    integer, intent(in) :: pres_level ! pressure level index 
    integer, intent(in) :: nx, ny ! grid dimensions
    real(kind=r_kind), dimension(nx,ny), intent(out) :: data_array ! retrieved
                                                                   ! data
    integer, intent(out) :: iret ! return code from getgb()

    integer :: npoints
    integer :: kg, kf, k
    integer, dimension(glob_w3_size) :: pds_mask, gds_mask ! search masks
    integer, dimension(glob_w3_size) :: pds_data, gds_data ! retrieved 
        ! values
    logical(kind=1), dimension(nx,ny) :: mask_array

    npoints = nx*ny
    pds_mask = -1
    gds_mask = -1
    pds_mask(5) = pds_def%i5
    pds_mask(6) = pds_def%i6
    pds_mask(7) = pres_level
    call getgb(glob_lu_in, 0, npoints, 0, pds_mask, gds_mask, kf, k, &
        pds_data, gds_data, mask_array, data_array, iret)
    where (.not. mask_array) data_array = glob_msng
end subroutine get_field

!----------------------------------------------------------------------------
subroutine calc_grid_parms(gds, nx, ny, dx, dy, f)
! calculates grid sizes and Coriolis force on lat-lon or Gaussian grid
    integer, dimension(:), intent(in) :: gds ! GDS section data
    integer, intent(in) :: nx, ny ! grid dimensions
    real(kind=r_kind), dimension(nx,ny), intent(out) :: dx, dy, f ! grid 
        ! size [m], Coriolis parameter

    integer :: i, j, k, kx, ky, nret
    real :: fi
    real, dimension(nx*ny) :: xpts, ypts, rlat, rlon, dummy
    real, parameter :: d2r = con_pi/180.0

    call gdswiz(gds, 0, nx*ny, -9999.0, xpts, ypts, rlon, rlat, nret, 0, &
        dummy, dummy) 
    if (nret /= nx*ny) stop 98 ! will never happen, I hope
    do k = 1, nx*ny
        fi = d2r*rlat(k)
        i = int(xpts(k))
        j = int(ypts(k))
        f(i,j) = 2.0*con_omega*sin(fi)
        if (i < nx) then
            kx = k+1
        else    ! wrap 
            kx = k-nx+1
        end if
        dx(i,j) = con_rerth*cos(fi)*abs(mod(rlon(kx)-rlon(k), 360.0))*d2r
        if (j < ny) then
            ky = k+nx   ! assumes order, should check whether ypts(ky) = j+1
            dy(i,j) = con_rerth*abs(mod(rlat(ky)-rlat(k), 360.0))*d2r
        end if
    end do
!    print *, '======dx', dx(1:4,1)
!    print *, '======dx', dx(1:4,ny/2)
!    print *, '======dy', dy(1:4,1)
!    print *, '======dy', dy(1:4,ny/2)
!    print *, '======f', f(1:4,1)
!    print *, '======f', f(1:4,ny/2)
!    stop 97
end subroutine calc_grid_parms

!----------------------------------------------------------------------------
subroutine alloc_input_storage(gds, cfg, model)
! allocates arrays allocated for model data storage
    integer, dimension(:), intent(in) :: gds ! GDS section data
    type(cfg_t), intent(in) :: cfg   ! configuration parameters
    type(input_data_t), intent(out) :: model ! arrays to hold input data

    integer :: i, nx, ny, np

    np = (cfg%pres_bot - cfg%pres_top)/glob_delta_p + 1
    nx = gds(2)
    ny = gds(3)
    model%np = np
    do i = 1, np
        model%p(i) = cfg%pres_bot - (i-1)*glob_delta_p
    end do
    model%nx = nx
    model%ny = ny
    allocate(model%dx(nx,ny))
    allocate(model%dy(nx,ny))
    allocate(model%f(nx,ny))
    allocate(model%sfc_pres(nx,ny))
    model%sfc_pres = glob_msng
    allocate(model%hgt(nx,ny,np))
    model%hgt = glob_msng
    allocate(model%t(nx,ny,np))
    model%t = glob_msng
    allocate(model%u_wnd(nx,ny,np))
    model%u_wnd = glob_msng
    allocate(model%v_wnd(nx,ny,np))
    model%v_wnd = glob_msng
    allocate(model%vvel(nx,ny,np))
    model%vvel = glob_msng
    allocate(model%rh(nx,ny,np))
    model%rh = glob_msng
    allocate(model%cld_cover(nx,ny,np))
    model%cld_cover = glob_msng
    allocate(model%conv_pres_bot(nx,ny))
    model%conv_pres_bot = glob_msng
    allocate(model%conv_pres_top(nx,ny))
    model%conv_pres_top = glob_msng
    allocate(model%tot_cld_cover(nx,ny))
    model%tot_cld_cover = glob_msng
    allocate(model%conv_cld_cover(nx,ny))
    model%conv_cld_cover = glob_msng
end subroutine alloc_input_storage

!----------------------------------------------------------------------------
subroutine free_input_storage(model)
! frees arrays allocated for model data storage
    type(input_data_t), intent(inout) :: model ! input data structure

    deallocate(model%dx)
    deallocate(model%dy)
    deallocate(model%f)
    deallocate(model%sfc_pres)
    deallocate(model%hgt)
    deallocate(model%t)
    deallocate(model%u_wnd)
    deallocate(model%v_wnd)
    deallocate(model%vvel)
    deallocate(model%rh)
    deallocate(model%cld_cover)
    deallocate(model%conv_pres_bot)
    deallocate(model%conv_pres_top)
    deallocate(model%tot_cld_cover)
    deallocate(model%conv_cld_cover)
end subroutine free_input_storage

!----------------------------------------------------------------------------
subroutine get_input_data(cfg, model)
! reads input data
    type(cfg_t), intent(in) :: cfg ! parameters read from cfg file
    type(input_data_t), intent(inout) :: model ! arrays to hold input data

    integer :: lvl, p, iret, nx, ny
    real(kind=r_kind) :: fp
    real(kind=r_kind), dimension(:,:), allocatable :: buf1, buf2, buf3
    character(len=*), parameter :: myself = 'get_input_data(): '

    nx = model%nx
    ny = model%ny
    call get_field(pds_sfc_pres, 0, nx, ny, model%sfc_pres, iret)
    if (iret /= 0) print *, myself, &
        'failed to retrieve sfc pres, iret = ', iret
    allocate(buf1(nx,ny))
    allocate(buf2(nx,ny))
    allocate(buf3(nx,ny))
    call get_field(pds_conv_pres_bot, 0, nx, ny, buf1, iret)
    if (iret /= 0) print *, myself, &
        'failed to retrieve pres at bottom of conv cloud, iret = ', iret
    call get_field(pds_conv_pres_top, 0, nx, ny, buf2, iret)
    if (iret /= 0) print *, myself, &
        'failed to retrieve pres at top of conv cloud, iret = ', iret
    call get_field(pds_conv_pcp_rate, 0, nx, ny, buf3, iret)
    if (iret /= 0) print *, myself, &
        'failed to retrieve conv precip rate, iret = ', iret
    ! ensure consistency for convective clouds
    where (buf1 /= glob_msng .and. buf2 /= glob_msng .and. buf3 /= glob_msng)
        model%conv_pres_bot = min(buf1, model%sfc_pres)
        model%conv_pres_top = buf2
        model%conv_cld_cover = fuzzy_log_member(cfg%pcp2cover, 1.0e6*buf3)
    elsewhere
        model%conv_pres_bot = glob_msng
        model%conv_pres_top = glob_msng
        model%conv_cld_cover = glob_msng
    end where
    call get_field(pds_tot_cld_cover, 0, nx, ny, model%tot_cld_cover, iret)
    if (iret /= 0) print *, myself, &
        'failed to retrieve total cloud cover, iret = ', iret
    do lvl = 1, model%np
        p = model%p(lvl)
        call get_field(pds_hgt, p, nx, ny, model%hgt(:,:,lvl), iret)
        if (iret /= 0) print *, myself, 'failed to retrieve Z at ', p, &
            ' hPa, iret = ', iret
        call get_field(pds_temp, p, nx, ny, model%t(:,:,lvl), iret)
        if (iret /= 0) print *, myself, 'failed to retrieve T at ', p, &
            ' hPa, iret = ', iret
        call get_field(pds_u_wnd, p, nx, ny, model%u_wnd(:,:,lvl), iret)
        if (iret /= 0) print *, myself, 'failed to retrieve U at ', p, &
            ' hPa, iret = ', iret
        call get_field(pds_v_wnd, p, nx, ny, model%v_wnd(:,:,lvl), iret)
        if (iret /= 0) print *, myself, 'failed to retrieve V at ', p, &
            ' hPa, iret = ', iret
        call get_field(pds_vvel, p, nx, ny, model%vvel(:,:,lvl), iret)
        if (iret /= 0) print *, myself, 'failed to retrieve VVEL at ', p, &
            ' hPa, iret = ', iret
        call get_field(pds_rh, p, nx, ny, model%rh(:,:,lvl), iret)
        if (iret /= 0) print *, myself, 'failed to retrieve RH at ', p, &
            ' hPa, iret = ', iret
        call get_field(pds_cld_w, p, nx, ny, buf1, iret) 
        if (iret /= 0) print *, myself, &
            'failed to retrieve cloud water at ', p, ' hPa, iret = ', iret
        fp = 100.0 * p
        where (buf1 /= glob_msng .and. model%t(:,:,lvl) /= glob_msng .and. &
            model%rh(:,:,lvl) /= glob_msng)
            model%cld_cover(:,:,lvl) = phys_cloud_cover(fp, model%t(:,:,lvl), &
                model%rh(:,:,lvl), buf1)
        elsewhere
            model%cld_cover(:,:,lvl) = glob_msng
        end where
    end do
    deallocate(buf1)
    deallocate(buf2)
    deallocate(buf3)
end subroutine get_input_data

!----------------------------------------------------------------------------
subroutine alloc_output_storage(products, nx, ny, cfg, waf)
    type(product_t), intent(in) :: products ! requested products
    integer, intent(in) :: nx, ny ! grid dimension
    type(cfg_t), intent(in) :: cfg   ! configuration parameters
    type(output_data_t), intent(out) :: waf ! output data structure

    integer :: ni, nc, nt

    waf%nx = nx
    waf%ny = ny
    ni = cfg%num_icng_lvls
    nc = cfg%num_cat_lvls
    nt = cfg%num_tcld_lvls
    waf%num_icng_lvls = ni
    waf%icng_lvls = cfg%icng_lvls
    waf%num_tcld_lvls = nt
    waf%tcld_lvls = cfg%tcld_lvls
    waf%num_cat_lvls = nc
    waf%cat_lvls = cfg%cat_lvls
    if (products%do_cb) then
        allocate(waf%cb_hgt_bot(nx,ny))
        allocate(waf%cb_hgt_top(nx,ny))
!        allocate(waf%cb_embd_hgt_bot(nx,ny))
!        allocate(waf%cb_embd_hgt_top(nx,ny))
        allocate(waf%cb_cover(nx,ny))
    end if
    if (products%do_icng) then
        allocate(waf%icng_mean(nx,ny,ni))
        allocate(waf%icng_max(nx,ny,ni))
    end if
    if (products%do_tcld) then
        allocate(waf%tcld_mean(nx,ny,nt))
        allocate(waf%tcld_max(nx,ny,nt))
    end if
    if (products%do_cat) then
        allocate(waf%cat_mean(nx,ny,nc))
        allocate(waf%cat_max(nx,ny,nc))
    end if
end subroutine alloc_output_storage

!----------------------------------------------------------------------------
subroutine free_output_storage(waf)
! frees arrays allocated for output data storage
    type(output_data_t), intent(inout) :: waf  ! output data structure

    if (allocated(waf%cb_hgt_bot)) deallocate(waf%cb_hgt_bot)
    if (allocated(waf%cb_hgt_top)) deallocate(waf%cb_hgt_top)
!    if (allocated(waf%cb_embd_hgt_bot)) &
!        deallocate(waf%cb_embd_hgt_bot)
!    if (allocated(waf%cb_embd_hgt_top)) &
!        deallocate(waf%cb_embd_hgt_top)
    if (allocated(waf%cb_cover)) deallocate(waf%cb_cover)

    if (allocated(waf%icng_mean)) deallocate(waf%icng_mean)
    if (allocated(waf%icng_max)) deallocate(waf%icng_max)

    if (allocated(waf%tcld_mean)) deallocate(waf%tcld_mean)
    if (allocated(waf%tcld_max)) deallocate(waf%tcld_max)

    if (allocated(waf%cat_mean)) deallocate(waf%cat_mean)
    if (allocated(waf%cat_max)) deallocate(waf%cat_max)
end subroutine free_output_storage

!----------------------------------------------------------------------------
subroutine write_output_data(products, cfg, pds, gds, waf, iret)
! writes output data to GRIB file
    type(product_t), intent(in) :: products ! requested products
    type(cfg_t), intent(in) :: cfg   ! configuration parameters
    integer, dimension(glob_w3_size), intent(in) :: pds, gds ! read from
        ! input file
    type(output_data_t), intent(in) :: waf ! products to write
    integer, intent(out) :: iret ! return code, 0 on success

    integer :: nx, ny, lvl, p

    nx = waf%nx
    ny = waf%ny
    iret = 0
    if (products%do_cb) then
        if (iret == 0) call put_waf_field(cfg%cb_hgt_bot_gparms, &
            0, pds, gds, nx, ny, waf%cb_hgt_bot, iret)
        if (iret == 0) call put_waf_field(cfg%cb_hgt_top_gparms, &
            0, pds, gds, nx, ny, waf%cb_hgt_top, iret)
!        if (iret == 0) call put_waf_field(cfg%cb_embd_hgt_bot_gparms, &
!            0, pds, gds, nx, ny, waf%cb_embd_hgt_bot, iret)
!        if (iret == 0) call put_waf_field(cfg%cb_embd_hgt_top_gparms, &
!            0, pds, gds, nx, ny, waf%cb_embd_hgt_top, iret)
        if (iret == 0) call put_waf_field(cfg%cb_cover_gparms, &
            0, pds, gds, nx, ny, waf%cb_cover, iret)
    end if
    if (products%do_tcld) then
        do lvl = 1, waf%num_tcld_lvls
            p = waf%tcld_lvls(lvl)
            call put_waf_field(cfg%tcld_mean_gparms, p, pds, gds, nx, ny, &
                waf%tcld_mean(:,:,lvl), iret)
            if (iret /= 0) exit
            call put_waf_field(cfg%tcld_max_gparms, p, pds, gds, nx, ny, &
                waf%tcld_max(:,:,lvl), iret)
            if (iret /= 0) exit
        end do
    end if
    if (products%do_cat) then
        do lvl = 1, waf%num_cat_lvls
            p = waf%cat_lvls(lvl)
            call put_waf_field(cfg%cat_mean_gparms, p, pds, gds, nx, ny, &
                waf%cat_mean(:,:,lvl), iret)
            if (iret /= 0) exit
            call put_waf_field(cfg%cat_max_gparms, p, pds, gds, nx, ny, &
                waf%cat_max(:,:,lvl), iret)
            if (iret /= 0) exit
        end do
    end if
    if (products%do_icng) then
        do lvl = 1, waf%num_icng_lvls
            p = waf%icng_lvls(lvl)
            call put_waf_field(cfg%icng_mean_gparms, p, pds, gds, nx, ny, &
                waf%icng_mean(:,:,lvl), iret)
            if (iret /= 0) exit
            call put_waf_field(cfg%icng_max_gparms, p, pds, gds, nx, ny, &
                waf%icng_max(:,:,lvl), iret)
            if (iret /= 0) exit
        end do
    end if
end subroutine write_output_data

end module waf_main

!===========================================================================
program wafavn
    use funcphys
    use waf_main
    use waf_cb
    use waf_config
    use waf_tcld
    use waf_cat
    use waf_icng

    implicit none

    character(len=256) :: cfg_file, input_file, output_file ! file names
    type(product_t) :: products ! flags indicating product to make
    type(cfg_t) :: cfg ! parameters set in a configuration file
    integer :: iret ! generic return code from subroutines
    integer, dimension(glob_w3_size) :: pds, gds ! arrays used by w3lib
    type(input_data_t) :: model_data ! input data structure
    type(output_data_t) :: waf_data ! output data structure
    
    call prog_args(cfg_file, input_file, output_file, products, iret)
    if (iret /= 0) stop 1
    call config_get_parms(products, cfg_file, cfg, iret)
    if (iret /= 0) stop 2
    call baopenr(glob_lu_in, input_file, iret)
    if (iret /= 0) then
        print *, 'baopenr() failed on ', input_file(:len_trim(input_file)), &
        ', iret = ', iret
        stop 3
    end if
    call get_grib_parms(pds, gds, iret)
    if (iret /= 0) stop 4
    call gfuncphys ! initialize funcphys package
    call alloc_input_storage(gds, cfg, model_data)
    call calc_grid_parms(gds, model_data%nx, model_data%ny, &
        model_data%dx, model_data%dy, model_data%f)
    call get_input_data(cfg, model_data)
    call baclose(glob_lu_in, iret)
    call alloc_output_storage(products, model_data%nx, model_data%ny, &
        cfg, waf_data)
    if (products%do_cb) call cb_alg(cfg, model_data, waf_data)
    if (products%do_tcld) call tcld_alg(cfg, model_data, waf_data)
    if (products%do_cat) call cat_alg(cfg, model_data, waf_data)
    if (products%do_icng) call icng_alg(cfg, model_data, waf_data)
    call free_input_storage(model_data)
    call baopenwt(glob_lu_out, output_file, iret)
    if (iret /= 0) then
        print *, 'baopenwt() failed on ', trim(output_file), ', iret = ', iret
        stop 6
    end if
    call write_output_data(products, cfg, pds, gds, waf_data, iret)
    call free_output_storage(waf_data)
    if (iret /= 0) stop 7
    call baclose(glob_lu_out, iret)
    stop 0
end program wafavn

! waf_icng.f90
! contains subroutines to calculate icing
! George Trojan, SAIC/EMC/NCEP, January 2007
! Last update: 03/07/07

module waf_icng

use fuzzy
use funcphys
use kinds
use physcons
use waf_filter
use waf_glob

implicit none

private
public icng_alg

integer, parameter :: num_layers = 6

type layer_t
    integer :: top_index
    integer :: base_index
    real(kind=r_kind) :: cloud_top_temp
end type layer_t

type layer_info_t
    integer :: num_layers
    type(layer_t), dimension(num_layers) :: layer
end type layer_info_t

contains
!----------------------------------------------------------------------------
! initializes layer_info_t structure
subroutine init_layer_info(layers)
    type(layer_info_t), intent(out) :: layers

    integer :: i

    forall (i=1:num_layers)
        layers%layer(i)%top_index = 0
        layers%layer(i)%base_index = 0
        layers%layer(i)%cloud_top_temp = -1.0
    end forall
    layers%num_layers = 0
end subroutine init_layer_info

!----------------------------------------------------------------------------
! returns index to the layer_info array or 0 if model layer k is not
! in a cloud
function f_layer_num(k, cloud_info)
    integer :: f_layer_num
    integer, intent(in) :: k
    type(layer_info_t), intent(in) :: cloud_info

    integer :: i

    do i = 1, cloud_info%num_layers
        if (k >= cloud_info%layer(i)%base_index .and. &
            k <= cloud_info%layer(i)%top_index) then
            f_layer_num = i
            return
        end if
    end do
    f_layer_num = 0
end function f_layer_num

!----------------------------------------------------------------------------
! calculates cloud layers information, for later use by the subroutine 
! get_cloud_top_temp
subroutine find_layers(nz, min_cld_cover, temperature, total_cover, layer_info)
    integer, intent(in) :: nz
    real(kind=r_kind), intent(in) :: min_cld_cover
    real(kind=r_kind), dimension(:), intent(in) :: temperature, &
        total_cover
    type(layer_info_t), intent(out) :: layer_info

    integer :: k, dry_level_count, idx_base, idx_below, idx_top
    logical :: in_cloud
    integer, parameter :: max_dry_levels = 3
    character(len=*), parameter :: me = 'find_layers(): '

    call init_layer_info(layer_info)
    in_cloud = total_cover(nz) >= min_cld_cover
    if (in_cloud) then
        layer_info%num_layers = 1
        layer_info%layer(1)%top_index = nz
        layer_info%layer(1)%cloud_top_temp = temperature(nz)
    end if
    dry_level_count = 0
    idx_base = 0
    do k = nz-1, 1, -1
        if (in_cloud) then
            if (total_cover(k) < min_cld_cover) then
                in_cloud = .false.
                dry_level_count = dry_level_count + 1
                idx_base = k 
            end if
        else
            if (total_cover(k) >= min_cld_cover) then
                in_cloud = .true.
                if (layer_info%num_layers >= num_layers) then
                    print *, me, 'too many cloud layers'
                    print *, '=====', layer_info
                    exit
                else if (layer_info%num_layers == 0) then 
                    ! first cloud layer
                    layer_info%num_layers = 1
                    layer_info%layer(layer_info%num_layers)%top_index = k + 1
                    dry_level_count = 0
                else if (dry_level_count < max_dry_levels) then 
                    ! in the cloud again
                    dry_level_count = 0
                    cycle
                else
                    ! new cloud layer
                    layer_info%layer(layer_info%num_layers)%base_index = &
                        idx_base
                    layer_info%num_layers = layer_info%num_layers + 1
                    layer_info%layer(layer_info%num_layers)%top_index = k + 1
                    dry_level_count = 0
                end if
            else
                dry_level_count = dry_level_count + 1
            end if
        end if
    end do
    ! if not set, set the base index of current layer
    if (in_cloud) then
        layer_info%layer(layer_info%num_layers)%base_index = 1
    else if (layer_info%layer(layer_info%num_layers)%base_index == 0) then
        layer_info%layer(layer_info%num_layers)%base_index = idx_base
    end if
    ! calculate cloud top temperatures
    do k = 1, layer_info%num_layers
        if (layer_info%layer(k)%cloud_top_temp < 0.0) then
            ! linear interpolation 
            idx_top = layer_info%layer(k)%top_index
            idx_below = layer_info%layer(k)%top_index - 1
            layer_info%layer(k)%cloud_top_temp = temperature(idx_below) - &
                (temperature(idx_below) - temperature(idx_top)) * &
                (total_cover(idx_below) - min_cld_cover)/ &
                (total_cover(idx_below) - total_cover(idx_top))
        end if
    end do
end subroutine find_layers

!----------------------------------------------------------------------------
! given layer info structure, calculates cloud top temperature
function f_cloud_top_temp(cloud_info, level)
    real(kind=r_kind) :: f_cloud_top_temp
    type(layer_info_t), intent(in) :: cloud_info
    integer, intent(in) :: level

    integer :: idx

    idx = f_layer_num(level, cloud_info)
    if (idx == 0) then
        f_cloud_top_temp = -1.0
    else
        f_cloud_top_temp = cloud_info%layer(idx)%cloud_top_temp
    endif
end function f_cloud_top_temp

!----------------------------------------------------------------------------
function f_icng_alg(fuzzy_t, fuzzy_conv_t, fuzzy_cld_cover, &
    fuzzy_cld_top_t, fuzzy_vvel, t, cld_cover, cld_top_t, vvel, conv_cld_cover)
    real(kind=r_kind) :: f_icng_alg
    type(fuzzy_set_t), intent(in) :: fuzzy_t, fuzzy_conv_t, &
        fuzzy_cld_cover, fuzzy_cld_top_t, fuzzy_vvel
    real(kind=r_kind), intent(in) :: t, cld_cover, cld_top_t, vvel, &
        conv_cld_cover
    
    real :: mem_t, mem_cld_cover, mem_cld_top_t, mem_vvel, icng

    if (conv_cld_cover > cld_cover) then
        mem_t = fuzzy_member(fuzzy_conv_t, t)
        ! Sligo limits convective cloud cover to 0.8
        mem_cld_cover = fuzzy_member(fuzzy_cld_cover, 1.25*conv_cld_cover)
        icng = mem_cld_cover*mem_t
    else
        mem_t = fuzzy_member(fuzzy_t, t)
        mem_cld_top_t = fuzzy_member(fuzzy_cld_top_t, cld_top_t)
        mem_cld_cover = fuzzy_member(fuzzy_cld_cover, cld_cover)
        icng = mem_cld_cover*mem_t*mem_cld_top_t
    end if
    if (icng > 0.0) then
        ! enhance icing potential with vertical velocity
        mem_vvel = fuzzy_member(fuzzy_vvel, vvel)
        if (vvel < 0.0) then
            f_icng_alg = icng + (1.0-icng)*mem_vvel
        else
            f_icng_alg = icng + icng*mem_vvel
        end if
    else
        f_icng_alg = 0.0
    end if
    f_icng_alg = icng
end function f_icng_alg

!----------------------------------------------------------------------------
subroutine icng_alg(cfg, model, waf)
    type(cfg_t), intent(in) :: cfg
    type(input_data_t), intent(in) :: model
    type(output_data_t), intent(inout) :: waf

    integer :: i, j, lvl, model_lvl, nx, ny
    real(kind=r_kind) :: fp, dy, cld_top_t, conv_cld_cover
    real(kind=r_kind), dimension(model%ny) :: dx
    logical :: is_convection
    real(kind=r_kind), dimension(:,:,:), allocatable :: icng
    type(layer_info_t) :: cloud_info
    character(len=*), parameter :: myself = 'icng_alg(): '

    nx = model%nx
    ny = model%ny
    dx = model%dx(1,:) ! works with lat-lon grid 
    dy = model%dy(1,1)
    allocate(icng(nx,ny,model%np))
    icng = cfg%icng_mean_gparms%msng
    do j = 1, ny
        do i = 1, nx
            ! set to missing below surface
            if (.not. all(model%cld_cover(i,j,:) /= glob_msng)) cycle
            ! find non-convective clouds
            call find_layers(model%np, cfg%icng_min_cld_cover, &
                model%t(i,j,:), model%cld_cover(i,j,:), cloud_info)
            do lvl = 1, model%np
                fp = 100.0*model%p(lvl)
                if (model%sfc_pres(i,j) < fp) cycle
                if (model%vvel(i,j,lvl) == glob_msng) cycle
                cld_top_t = f_cloud_top_temp(cloud_info, lvl)
                if (model%conv_cld_cover(i,j) /= glob_msng .and. &
                    fp > model%conv_pres_top(i,j) .and. &
                    fp <= model%conv_pres_bot(i,j)) then
                    conv_cld_cover = model%conv_cld_cover(i,j)
                else
                    conv_cld_cover = 0.0
                end if
                icng(i,j,lvl) = f_icng_alg(cfg%icng_t, cfg%icng_conv_t, &
                    cfg%icng_cld_cover, cfg%icng_cld_top_t, cfg%icng_vvel, &
                    model%t(i,j,lvl), model%cld_cover(i,j,lvl), cld_top_t, &
                    model%vvel(i,j,lvl), conv_cld_cover)
            end do
        end do
    end do
    do lvl = 1, waf%num_icng_lvls
        model_lvl = glob_find_index(waf%icng_lvls(lvl), model%p, model%np)
        call filter_avg3d(nx, ny, model%np, model_lvl, icng, dx, dy, &
            glob_delta_p, cfg%icng_cell%dxdy, cfg%icng_cell%dp, &
            cfg%icng_mean_gparms%msng, mask=icng>=0.0, &
            amean=waf%icng_mean(:,:,lvl), amax=waf%icng_max(:,:,lvl))
    end do
    deallocate(icng)
end subroutine icng_alg
    
end module waf_icng

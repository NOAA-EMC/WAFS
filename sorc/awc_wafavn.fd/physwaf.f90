! physwaf.f90
! a few elemental functions
! George Trojan, SAIC/EMC/NCEP, May 2007
! Last update: 03/05/07

module physwaf
use kinds
use physcons
use funcphys
implicit none

contains
!----------------------------------------------------------------------------
elemental function physwaf_icao_hgt(p)
! calculates ICAO height given pressure
    real(kind=r_kind) physwaf_icao_hgt
    real(kind=r_kind), intent(in) :: p

    real(kind=r_kind), parameter :: lapse = 6.5e-3
    real(kind=r_kind), parameter :: t_sfc = 288.15
    real(kind=r_kind), parameter :: t_strat = 216.65
    real(kind=r_kind), parameter :: alpha_sfc = t_sfc/lapse
    real(kind=r_kind), parameter :: alpha_strat = -con_rd*t_strat/con_g
    real(kind=r_kind), parameter :: kappa = con_rd/con_g*lapse
    real(kind=r_kind), parameter :: p_strat = 22631.7

    if (p >= p_strat) then
        physwaf_icao_hgt = alpha_sfc * (1.0 - (p/con_p0)**kappa)
    else
        physwaf_icao_hgt = 11000.0 + alpha_strat * log(p/p_strat)
    end if
end function physwaf_icao_hgt

!----------------------------------------------------------------------------
elemental function physwaf_t_rh2td(t, rh)
! calculates dew point given temperature and relative humidity.
    real(kind=r_kind) physwaf_t_rh2td
    real(kind=r_kind), intent(in) :: t, rh

    real(kind=r_kind) :: vp

    vp = rh * fpvs(t)
    physwaf_t_rh2td = ftdp(vp)
end function physwaf_t_rh2td

!----------------------------------------------------------------------------
elemental function physwaf_q2rh(p, t, q)
! calculates relative humidity
    real(kind=r_kind) physwaf_q2rh
    real(kind=r_kind), intent(in) :: p, t, q

    physwaf_q2rh = p*q/(con_eps*fpvs(t))
end function physwaf_q2rh

!----------------------------------------------------------------------------
elemental function physwaf_cloud_cover(p, t, q, clw)
! calculates cloud cover. Code extractewd from subroutine progcld1
! requires previous call to subroutine gpvsl from module funcphys
    real(kind=r_kind) physwaf_cloud_cover
    real(kind=r_kind), intent(in) :: p, t, q, clw

    real(kind=r_kind) :: rh, onemrh, qs, tem1, tem2, val

    rh = physwaf_q2rh(p, t, q)
    onemrh = max(1.0e-10, 1.0-rh)
    qs = con_eps * fpvsl(t)/p
    tem1 = 2.0e3/min(max(sqrt(sqrt(onemrh*qs)), 1.0e-4), 1.0)
    val = max(min(tem1*clw, 50.0), 0.0)
    tem2 = sqrt(sqrt(rh))
    physwaf_cloud_cover = max(tem2*(1.0 - exp(-val)), 0.0)
end function physwaf_cloud_cover

!----------------------------------------------------------------------------
elemental function physwaf_theta_e(t, q, p)
! calculates equivalent potential temperature
! Vapour pressure formula 2.19 in R.R.Rogers & M.K.Yau, 
! 'A Short Course in Cloud Physics', Pergamon Press, 1991
    real(kind=r_kind) physwaf_theta_e
    real(kind=r_kind), intent(in) :: t, q, p

    real(kind=r_kind) :: theta, vp, tlcl

    theta = t/fpkap(p)
    vp = q*p/((1.0-con_eps)*q + con_eps)
    tlcl = ftlcl(t, t-ftdpl(vp))
    physwaf_theta_e = fthe(tlcl, tlcl/theta)
end function physwaf_theta_e

!----------------------------------------------------------------------------
elemental function physwaf_equiv_pot_vort(du_dp, dv_dp, du_dy, dv_dx, &
    dthe_dx, dthe_dy, dthe_dp, f)
! calculates equivalent potential vorticity
! Uses formula (3) from Donald McCann, 'Three-dimensional Computations of
! Equivalent Potential Vorticity', Weather and Forecasting 10 (1995), 
! pp 798-802
    real(kind=r_kind) :: physwaf_equiv_pot_vort
    real(kind=r_kind), intent(in) :: du_dp, dv_dp, du_dy, dv_dx, &
        dthe_dx, dthe_dy, dthe_dp, f

    physwaf_equiv_pot_vort = con_g*(dthe_dx*dv_dp-dthe_dy*du_dp - &
        (dv_dx-du_dy+f)*dthe_dp)
    if (f < 0.0) physwaf_equiv_pot_vort = -physwaf_equiv_pot_vort ! FIXME 
end function physwaf_equiv_pot_vort

!----------------------------------------------------------------------------
elemental function physwaf_ti1(du_dx, du_dy, dv_dx, dv_dy, du_dh, dv_dh)
! calculates turbulence following Ellrod algoritm
!   (Gary P. Ellrod: Weather and Forecasting, vol 7, pp 150-165, 1992)
!   turb = 1.0e7 * vws * (def - div)
!   where 
!      vws = |d(u,v)/dz|
!      def = sqrt(dst^2+dsh^2)
!          dst = du/dx-dv/dy, dsh = dv/dx+du/dy
!      div = du/dx+dv/dy
!   Index TI1 does not use div
! The output in scaled by a factor 1.0e7
    real(kind=r_kind) physwaf_ti1
    real(kind=r_kind), intent(in) :: du_dx, du_dy, dv_dx, dv_dy, du_dh, dv_dh

    real(kind=r_kind) :: vws2, def2

    vws2 = du_dh**2 + dv_dh**2
    def2 = (du_dx-dv_dy)**2 + (dv_dx+du_dy)**2
    physwaf_ti1 = 1.0e7*sqrt(vws2*def2)
end function physwaf_ti1

end module physwaf

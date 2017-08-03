FUNCTION compute_F( t, x_bar, h ) RESULT( f )
  USE m_constants, ONLY : PI
  IMPLICIT NONE 
  REAL(8) :: t, x_bar, h
  REAL(8) :: f
  !
  COMPLEX(8) :: z, w_iz
  REAL(8) :: f_re, f_im

  f = 0.d0

  IF(x_bar < 1.d-30) THEN 
    f = sqrt(h) * erf(PI/(2.d0*h*t))
  ELSE 
    z = cmplx( PI/(2.d0*h*t), t*x_bar*h, kind=8 )
    CALL Cwrap_faddeeva( real(z,kind=8), aimag(z), f_re, f_im )
    w_iz = cmplx( f_re, f_im, kind=8 )
    f = exp( -t*t*x_bar*x_bar )
    f = f - REAL( exp( -t*t*x_bar*x_bar - z*z ) * w_iz, kind=8 )
    f = sqrt(h)*f
  ENDIF 
END FUNCTION 




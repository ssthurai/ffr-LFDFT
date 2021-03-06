MODULE m_constants
  IMPLICIT NONE 
  REAL(8), PARAMETER :: PI=4.d0*atan(1.d0)
  REAL(8), PARAMETER :: FOURPI=4.D0*PI
  REAL(8), PARAMETER :: TWOPI=2.d0*PI
  REAL(8), PARAMETER :: EPS_SMALL = epsilon(1.d0)
  !
  REAL(8), PARAMETER :: Ry2eV=13.6058d0 ! Ry to eV
  REAL(8), PARAMETER :: ANG2BOHR = 1.889725989d0
END MODULE

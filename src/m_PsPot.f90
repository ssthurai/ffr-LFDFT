MODULE m_PsPot

  USE m_Ps_HGH, ONLY : Ps_HGH_Params_T
  IMPLICIT NONE 

  CHARACTER(128) :: PsPot_Dir = './HGH/'
  CHARACTER(128), ALLOCATABLE :: PsPot_FilePath(:)

  TYPE(Ps_HGH_Params_T), ALLOCATABLE :: Ps_HGH_Params(:)

  INTEGER :: NbetaNL  ! max(NbetaNL)
  REAL(8), ALLOCATABLE :: betaNL(:,:) ! (Npoints,NbetaNL)

  INTEGER, ALLOCATABLE :: prj2beta(:,:,:,:) ! (iprj,Natoms,l,m)

  INTEGER :: NprojTotMax

END MODULE 



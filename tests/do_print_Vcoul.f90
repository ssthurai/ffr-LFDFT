PROGRAM do_print_V_ps_loc

  USE m_PsPot, ONLY : PsPot_Dir
  USE m_LF3d, ONLY : xyz2lin => LF3d_xyz2lin, &
                     lingrid => LF3d_lingrid
  USE m_hamiltonian, ONLY : V_ps_loc
  USE m_atoms, ONLY : strf => StructureFactor
  IMPLICIT NONE 
  INTEGER :: Narg
  INTEGER :: NN(3)
  REAL(8) :: AA(3), BB(3)
  CHARACTER(64) :: filexyz, arg_N
  INTEGER :: ip, N_in, ix, iy, iz
  REAL(8) :: shift

  Narg = iargc()
  IF( Narg /= 2 ) THEN 
    WRITE(*,*) 'ERROR: exactly two arguments must be given:'
    WRITE(*,*) '       N and path to structure file'
    STOP 
  ENDIF 

  CALL getarg( 1, arg_N )
  READ(arg_N, *) N_in

  CALL getarg( 2, filexyz )

  CALL init_atoms_xyz(filexyz)

  ! Override PsPot_Dir
  PsPot_Dir = '../HGH/'
  CALL init_PsPot()

  !
  NN = (/ N_in, N_in, N_in /)
  AA = (/ 0.d0, 0.d0, 0.d0 /)
  BB = (/ 16.d0, 16.d0, 16.d0 /)
  CALL init_LF3d_p( NN, AA, BB )

  CALL info_atoms()
  CALL info_PsPot()
  CALL info_LF3d()

  ! Initialize occupation numbers
  CALL init_states()

  CALL init_strfact()

  CALL calc_Ewald()

  CALL alloc_hamiltonian()

  CALL init_V_coul_G()

  !iy = NN(2)/2 + 1
  !iz = NN(3)/2 + 1
  ix = 1
  iz = 1
  WRITE(*,*) 'ix iz = ', ix, iz
  WRITE(*,*) 'sum(strf) = ', sum(strf)
  shift = 0.5d0*( lingrid(1,2) - lingrid(1,1) ) ! shift to get the usual FFT grid, only works for Nx=Ny=Nz
  WRITE(*,*) 'shift = ', shift
  DO iy = 1,NN(2)
    ip = xyz2lin(ix,iy,iz)
    WRITE(N_in+1,'(2F22.12)') lingrid(2,ip)-shift, V_ps_loc(ip)
  ENDDO 

  CALL dealloc_hamiltonian()
  CALL dealloc_LF3d()
  CALL dealloc_PsPot()
  CALL dealloc_atoms()

END PROGRAM


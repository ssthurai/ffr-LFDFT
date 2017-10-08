PROGRAM eggbox_grid_cube

  USE m_constants, ONLY : Ry2eV
  USE m_options, ONLY : FREE_NABLA2
  USE m_PsPot, ONLY : PsPot_Dir, NbetaNL
  USE m_LF3d, ONLY : Npoints => LF3d_Npoints
  USE m_states, ONLY : Nstates, Focc, &
                       evals => KS_evals, &
                       evecs => KS_evecs
  !
  USE m_atoms, ONLY : atpos => AtomicCoords
  USE m_hamiltonian, ONLY : V_ps_loc, Rhoe, V_ps_loc_long
  USE m_energies, ONLY : E_ps_loc
  USE m_LF3d, ONLY : dVol => LF3d_dVol
  USE m_options, ONLY : T_PRINT_INTEG_RHO, I_ALG_DIAG, ETHR_EVALS
  USE m_constants, ONLY : ANG2BOHR
  USE m_grid_atom_cube, ONLY : Npoints_a, dVol_a
  !
  IMPLICIT NONE 
  INTEGER :: Narg
  INTEGER :: NN(3)
  REAL(8) :: hh(3), AA(3), BB(3)
  CHARACTER(64) :: filexyz, arg_N
  INTEGER :: ip, ist, N_in
  INTEGER :: iargc  ! pgf90 
  INTEGER :: tstart, counts_per_second, tstop
  CHARACTER(1) :: typ
  REAL(8) :: center(3)
  REAL(8), ALLOCATABLE :: V_short_a(:)

  CALL system_clock( tstart, counts_per_second )

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
  ! so that coord given in xyz file is in bohr
  atpos(:,:) = atpos(:,:)/ANG2BOHR  

  ! Override PsPot_Dir
  PsPot_Dir = '../HGH/'
  CALL init_PsPot()

  typ = 'p'
  IF( typ == 's' ) THEN 
    NN = (/ N_in, N_in, N_in /)
    hh(:) = (/1.d0, 1.d0, 1.d0/)*(16.d0/(NN(1)-1))
    CALL init_LF3d_sinc( NN, hh )
  ELSE ! typ == 'p'
    NN = (/ N_in, N_in, N_in /)
    AA = (/ 0.d0, 0.d0, 0.d0 /)
    BB = (/ 16.d0, 16.d0, 16.d0 /)
    CALL init_LF3d_p( NN, AA, BB )
  ENDIF 

  CALL info_atoms()
  CALL info_PsPot()
  CALL info_LF3d()

! Only use local pseudopotential
  ! CALL init_betaNL()
  NbetaNL = 0

  ! Initialize occupation numbers
  CALL init_states()

  IF( typ == 'p' ) THEN 
    CALL init_strfact_shifted()
  ENDIF 

  ! Memory for potentials
  CALL alloc_hamiltonian()

  ! Local pseudopotential
  IF( typ == 'p' ) THEN 
    CALL init_V_ps_loc_G()
  ELSE 
    CALL init_V_ps_loc()
  ENDIF 

  ! Local pseudopotential (long part)
  ! FIXME: only for periodic CASE
  ALLOCATE( V_ps_loc_long(Npoints) )
  CALL init_V_ps_loc_G_long()

  !
  center(:) = atpos(:,1)
  CALL init_grid_atom_cube( center, 1.5d0, 50 )
  !
  ALLOCATE( V_short_a(Npoints_a) )
  CALL init_V_ps_loc_short( center, V_short_a )

  ! Laplacian matrix
  CALL init_nabla2_sparse()
  ! ILU0 preconditioner based on kinetic matrix
  CALL init_ilu0_prec()

  IF( FREE_NABLA2 ) THEN 
    CALL dealloc_nabla2_sparse()
  ENDIF 

  ! Manually allocate KS eigenvectors and eigenvalues
  ALLOCATE( evecs(Npoints,Nstates), evals(Nstates) )

  ! Initialize to random wavefunction
  DO ist = 1, Nstates
    DO ip = 1, Npoints
      CALL random_number( evecs(ip,ist) )
    ENDDO
  ENDDO
  CALL orthonormalize( Nstates, evecs )

  
  ! Diagonalize
  I_ALG_DIAG = 2
  ETHR_EVALS = 1d-5;
  CALL Sch_solve_diag()

  ! Calculate electron density
  T_PRINT_INTEG_RHO = .TRUE.
  CALL calc_rhoe( Focc, evecs )


  ! Calculate local pseudopotential energy
  E_ps_loc = sum( Rhoe(:) * V_ps_loc(:) )*dVol
  WRITE(*,*)
  WRITE(*,'(1x,A,F18.10)') 'E_ps_loc = ', E_ps_loc

  WRITE(*,'(1x,F18.10)') sum(V_short_a)*dVol_a + sum(V_ps_loc_long)*dVol


  CALL dealloc_nabla2_sparse()
  CALL dealloc_ilu0_prec()
  CALL dealloc_hamiltonian()
  CALL dealloc_LF3d()
  CALL dealloc_PsPot()
  CALL dealloc_atoms()

  CALL system_clock( tstop )

  WRITE(*,*)
  WRITE(*,*) 'Total elapsed time: ', dble(tstop - tstart)/counts_per_second, ' second.'
  WRITE(*,*)

END PROGRAM 

SUBROUTINE init_V_ps_loc_short( center, V_short_a )
  USE m_grid_atom_cube, ONLY : Npoints_a, grid_a
  USE m_LF3d, ONLY : LL => LF3d_LL
  USE m_PsPot, ONLY : Ps => Ps_HGH_Params
  USE m_Ps_HGH, ONLY : hgh_eval_Vloc_R_short
  IMPLICIT NONE 
  REAL(8) :: center(3)
  REAL(8) :: V_short_a(Npoints_a)
  INTEGER :: ip, isp
  REAL(8) :: dr_vec(3)
  REAL(8) :: dr

  isp = 1
  DO ip = 1,Npoints_a
    CALL calc_dr_periodic_1pnt( LL, center, grid_a(:,ip), dr_vec )
    dr = sqrt( dr_vec(1)**2 + dr_vec(2)**2 + dr_vec(3)**2 )
    V_short_a(ip) = hgh_eval_Vloc_R_short( Ps(isp), dr ) 
  ENDDO 
  WRITE(*,*) 'sum(V_short_a) = ', sum(V_short_a)

END SUBROUTINE 



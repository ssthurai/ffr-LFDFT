!!>
!!> \section{Subroutine \texttt{Sch\_solve\_Emin\_pcg}}
!!>
!!> This subroutine solves one-particle Schrodinger equations by minimizing band energy.
!!> functional using conjugate gradient algorithm.
!!> The algorithm is based on T.A. Arias notes.
!!>
!!> ILU0 preconditioner from SPARSKIT is used as preconditioner.
!!>
!!> AUTHOR: Fadjar Fathurrahman

SUBROUTINE Sch_solve_Emin_pcg( linmin_type, alpha_t, restart, Ebands_CONV_THR, &
                               Ebands_NiterMax, verbose )
!!>
!!> The following variables are imported.
!!>
  USE m_LF3d, ONLY : Npoints => LF3d_Npoints, dVol => LF3d_dVol
  USE m_states, ONLY : Nstates, v => KS_evecs, evals => KS_evals
  USE m_options, ONLY : I_CG_BETA, T_WRITE_RESTART
  !
  IMPLICIT NONE
  !
  INTEGER :: linmin_type
  REAL(8) :: alpha_t  ! step size
  LOGICAL :: restart
  REAL(8) :: Ebands_CONV_THR
  INTEGER :: Ebands_NiterMax
  LOGICAL :: verbose
  !
  REAL(8), ALLOCATABLE :: g(:,:), g_old(:,:), g_t(:,:)
  REAL(8), ALLOCATABLE :: d(:,:), d_old(:,:)
  REAL(8), ALLOCATABLE :: Kg(:,:), Kg_old(:,:) ! preconditioned
  REAL(8), ALLOCATABLE :: tv(:,:)
  REAL(8) :: alpha, beta, num, denum, Ebands_old, Ebands, diff_Ebands
  !
  REAL(8), ALLOCATABLE :: evals_old(:)
  REAL(8) :: RNORM
  INTEGER :: iter, ist
  !
  REAL(8) :: dir_deriv, curvature, Ebands_trial
  REAL(8) :: beta_FR, beta_PR, beta_HS, beta_DY, calc_dir_deriv
  !
  REAL(8) :: ddot

!!> Display several informations about the algorithm
  IF( verbose ) THEN 
    CALL info_Sch_solve_Emin_pcg( linmin_type, alpha_t, restart, Ebands_CONV_THR, Ebands_NiterMax )
  ENDIF 

!!> Here we allocate all working arrays
  ALLOCATE( g(Npoints,Nstates) )  ! gradient
  ALLOCATE( g_old(Npoints,Nstates) ) ! old gradient
  ALLOCATE( d(Npoints,Nstates) )  ! direction
  ALLOCATE( d_old(Npoints,Nstates) )  ! old direction

  ALLOCATE( Kg(Npoints,Nstates) )  ! preconditioned gradient
  ALLOCATE( Kg_old(Npoints,Nstates) ) ! old preconditioned gradient

  ALLOCATE( tv(Npoints,Nstates) )  ! temporary vector for calculating trial gradient

  ALLOCATE( evals_old(Nstates) )

  ! Read starting eigenvectors from file
  ! FIXME: This is no longer relevant
  IF( restart ) THEN
    READ(112) v   ! FIXME Need to use file name
  ENDIF

!!> Calculate initial total energy from given initial guess of wave function
  CALL calc_Ebands( Nstates, v, evals, Ebands )

!!> Save the initial Ebands
  Ebands_old = Ebands

  evals_old(:) = evals(:)

!!> initialize alpha and beta
  alpha = 0.d0
  beta  = 0.d0

!!> zero out all working arrays
  g(:,:)     = 0.d0
  d(:,:)     = 0.d0
  d_old(:,:) = 0.d0
  Kg(:,:)    = 0.d0
  Kg_old(:,:) = 0.d0

!!> \texttt{g\_t} is required when using line minimization based on trial gradient.
  IF( linmin_type == 2 ) THEN 
    ALLOCATE( g_t(Npoints,Nstates) )  ! trial gradient
    g_t(:,:)   = 0.d0
  ENDIF 


!!> Here the iteration starts:
  DO iter = 1, Ebands_NiterMax
!!>
!!> Evaluate gradient at current trial vectors
    CALL calc_grad( Nstates, v, g )
    !
!!> Precondition the gradient using ILU0 preconditioner from SPARSKIT
!!>
    DO ist = 1, Nstates
      CALL prec_ilu0( g(:,ist), Kg(:,ist) )
    ENDDO
!!
!!> set search direction
!
    IF( iter /= 1 ) THEN
      SELECT CASE ( I_CG_BETA )
      CASE(1)
!!> Fletcher-Reeves formula
!!> \begin{verbatim}
!!>     beta = sum( g * Kg ) / sum( g_old * Kg_old )
!!> \end{verbatim}
!!>
        beta = beta_FR( Npoints*Nstates, g, g_old, Kg, Kg_old )
!!>
      CASE(2)
!!> Polak-Ribiere formula
!!> \begin{verbatim}
!!>     beta = sum( (g-g_old)*Kg ) / sum( g_old * Kg_old )
!!> \end{verbatim}
!!>
        beta = beta_PR( Npoints*Nstates, g, g_old, Kg, Kg_old )
!!>
      CASE(3)
!!> Hestenes-Stiefeld formula
!!> \begin{verbatim}
!!>     beta = sum( (g-g_old)*Kg ) / sum( (g-g_old)*d_old )
!!> \end{verbatim}
!!>
        beta = beta_HS( Npoints*Nstates, g, g_old, Kg, d_old )
!!>
      CASE(4)
!!> Dai-Yuan formula
!!> \begin{verbatim}
!!>     beta = sum( g * Kg ) / sum( (g-g_old)*d_old )
!!> \end{verbatim}
!!>
        beta = beta_DY( Npoints*Nstates, g, g_old, Kg, d_old )
!!>
      END SELECT
    ENDIF
!!>
!!> Reset CG is beta is found to be smaller than zero
!!>
    IF( beta < 0 ) THEN
      WRITE(*,'(1x,A,F18.10,A)') 'beta is smaller than zero: ', beta, ': setting it to zero'
    ENDIF
    beta = max( 0.d0, beta )
!!>
!!> Compute new direction
!!>
    d(:,:) = -Kg(:,:) + beta*d_old(:,:)
!!>
!!> Evaluate gradient at trial step
!!>
    tv(:,:) = v(:,:) + alpha_t * d(:,:)
    CALL orthonormalize( Nstates, tv )


    ! Line minimization
    IF( linmin_type == 1 ) THEN 
      !
      ! dir_deriv = 2.d0*sum( d*g )*dVol  ! need dVol !!!
      dir_deriv = calc_dir_deriv( Npoints*Nstates, d, g )*dVol
      CALL calc_Ebands( Nstates, tv, evals, Ebands_trial )
      curvature = ( Ebands_trial - ( Ebands + alpha_t*dir_deriv ) ) / alpha_t**2
      alpha = abs(dir_deriv/(2.d0*curvature))
    ELSE
      ! Using gradient
      CALL calc_grad( Nstates, tv, g_t )
      ! Compute estimate of best step and update current trial vectors
      !denum = sum( (g - g_t) * d )
      denum = ddot( Nstates*Npoints, g, 1, d, 1) - ddot( Nstates*Npoints, g_t, 1, d, 1 )
      num = ddot( Nstates*Npoints, g, 1, d, 1 )
      IF( denum /= 0.d0 ) THEN  ! FIXME: use abs ?
        alpha = abs( alpha_t * num/denum )
      ELSE
        alpha = 0.d0
      ENDIF
    ENDIF 

    v(:,:) = v(:,:) + alpha * d(:,:)
    CALL orthonormalize( Nstates, v )

    CALL calc_Ebands( Nstates, v, evals, Ebands )
    diff_Ebands = Ebands - Ebands_old

    RNORM = SUM( abs(evals - evals_old) )/REAL(Nstates, kind=8)

    IF( verbose ) THEN 
      WRITE(*,*)
      WRITE(*,'(1x,A,I8,ES18.10)') 'Sch_solve_Emin_pcg: iter, RNORM ', iter, RNORM
      WRITE(*,'(1x,A,I8,F18.10,ES18.10)') 'Sch_solve_Emin_pcg Ebands ', iter, Ebands, diff_Ebands
      WRITE(*,*) 'Eigenvalues convergence:'
      DO ist = 1,Nstates
        WRITE(*,'(1X,I5,F18.10,ES18.10)') ist, evals(ist), abs( evals(ist)-evals_old(ist) )
      ENDDO 
    ENDIF 
    !
    IF( abs(diff_Ebands) < Ebands_CONV_THR ) THEN
      WRITE(*,*)
      WRITE(*,*) 'Sch_solve_Emin_pcg: Convergence achieved based on diff_Ebands'
      EXIT
    ELSEIF( RNORM < Ebands_CONV_THR ) THEN 
      WRITE(*,*)
      WRITE(*,*) 'Sch_solve_Emin_pcg: Convergence achieved based on RNORM'
      EXIT
    ENDIF
    !
    Ebands_old = Ebands
    evals_old(:) = evals(:)
    g_old(:,:) = g(:,:)
    d_old(:,:) = d(:,:)
    Kg_old(:,:) = Kg(:,:)
    flush(6)
  ENDDO

  IF( T_WRITE_RESTART ) THEN
    WRITE(111) v
  ENDIF

  DEALLOCATE( evals_old )
  DEALLOCATE( g, g_old, d, d_old, tv, Kg, Kg_old )
  IF( linmin_type == 2 ) THEN 
    DEALLOCATE( g_t )
  ENDIF 
END SUBROUTINE


!!>
!!> The following subroutine reports various information related to CG minimization
!!> of for diagonalizing Schrodinger equation.
!!>
SUBROUTINE info_Sch_solve_Emin_pcg( linmin_type, alpha_t, restart, Ebands_CONV_THR, &
                                    Ebands_NiterMax )
  USE m_options, ONLY : I_CG_BETA
  USE m_LF3d, ONLY : Npoints => LF3d_Npoints
  USE m_states, ONLY : Nstates
  IMPLICIT NONE
  !
  INTEGER :: linmin_type
  REAL(8) :: alpha_t
  LOGICAL :: restart
  REAL(8) :: Ebands_CONV_THR
  INTEGER :: Ebands_NiterMax
  !
  REAL(8) :: memGB

!!> The following is \textbf{hard-wired} calculation. It may need to be updated
!!> if the actual code is modified
!!>
  memGB = Npoints*Nstates*8d0 * 8d0 / (1024d0*1024d0*1024.d0)

  WRITE(*,*)
  WRITE(*,*) 'Minimization of Ebands using PCG algorithm (solving Schrodinger equation):'
  WRITE(*,*) '--------------------------------------------------------------------------'
  WRITE(*,*)
  WRITE(*,'(1x,A,I8)')     'NiterMax = ', Ebands_NiterMax
  WRITE(*,'(1x,A,ES10.3)') 'alpha_t  = ', alpha_t
  WRITE(*,*)               'restart  = ', restart
  WRITE(*,'(1x,A,ES10.3)') 'conv_thr = ', Ebands_CONV_THR
  WRITE(*,*)
  IF( I_CG_BETA == 1 ) THEN
    WRITE(*,*) 'Using Fletcher-Reeves formula'
  ELSEIF( I_CG_BETA == 2 ) THEN
    WRITE(*,*) 'Using Polak-Ribiere formula'
  ELSEIF( I_CG_BETA == 3 ) THEN
    WRITE(*,*) 'Using Hestenes-Stiefel formula'
  ELSEIF( I_CG_BETA == 4 ) THEN
    WRITE(*,*) 'Using Dai-Yuan formula'
  ELSE
    ! This line should not be reached.
    WRITE(*,*) 'XXXXX WARNING: Unknown I_CG_BETA: ', I_CG_BETA
  ENDIF
  WRITE(*,*)
  IF( linmin_type == 1 ) THEN 
    WRITE(*,*) 'Using quadratic line minimization based on energy'
  ELSEIF( linmin_type == 2 ) THEN 
    WRITE(*,*) 'Using line minimizing based on gradient'
  ELSE 
    ! This line should not be reached
    WRITE(*,*) 'XXXXX WARNING: Unknown linmin_type: ', linmin_type
  ENDIF 
  WRITE(*,*)
  WRITE(*,'(1x,A,F18.10)') 'KS_solve_Emin_pcg: memGB = ', memGB

END SUBROUTINE


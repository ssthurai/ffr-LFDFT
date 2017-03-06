SUBROUTINE davidson( )

  IMPLICIT NONE
  ! Arguments
  INTEGER :: IK
  INTEGER :: NBASIS, NSTATES
  !COMPLEX(8) :: H(NBASIS,NBASIS)
  COMPLEX(8) :: v(NBASIS,NSTATES)
  REAL(8) :: EVALS(NSTATES)
  REAL(8) :: PREC(NBASIS)
  INTEGER :: NNR
  REAL(8) :: RHOE(NNR)
  ! Local variable
  REAL(8) :: RNORM
  INTEGER :: IST, ISTEP, I, J, MAX_DIR, NCONV
  LOGICAL :: IS_CONVERGED
  REAL(8) :: MACHINE_ZERO, TOLERANCE
  REAL(8), ALLOCATABLE :: RES_TOL(:), RES_NORM(:), EVALS_RED(:)
  COMPLEX(8) :: Z_ZERO, Z_ONE
  COMPLEX(8), ALLOCATABLE :: CMAT(:,:), H_MAT(:,:), O_MAT(:,:), EVEC(:,:)
  COMPLEX(8), ALLOCATABLE :: HV(:,:), R(:,:), HR(:,:), XTEMP(:,:)
  ! BLAS function
  COMPLEX(8) :: ZDOTC

  Z_ZERO = CMPLX(0.D0,0.D0)
  Z_ONE  = CMPLX(1.D0,0.D0)

  ALLOCATE( RES_TOL(NSTATES) )
  ALLOCATE( RES_NORM(NSTATES) )
  ALLOCATE( CMAT(NSTATES,NSTATES) )
  ALLOCATE( H_MAT(2*NSTATES,2*NSTATES) )
  ALLOCATE( O_MAT(2*NSTATES,2*NSTATES) )
  ALLOCATE( EVEC(2*NSTATES,2*NSTATES) )
  ALLOCATE( EVALS_RED(2*NSTATES) )
  ALLOCATE( HV(NBASIS,NSTATES) )
  ALLOCATE( R(NBASIS,NSTATES) )
  ALLOCATE( HR(NBASIS,NSTATES) )
  ALLOCATE( XTEMP(NBASIS,NSTATES) )

  V(:,:) = Z_ZERO
  DO IST=1,NSTATES
    V(IST,IST) = Z_ONE;
  ENDDO

  ! Apply Hamiltonian
  DO I=1,NSTATES
    CALL APPLY_HAM(V(:,I), HV(:,I), NBASIS, IK, RHOE, NNR) 
  ENDDO

  ! Calculate Rayleigh quotient
  !call multiply(v,hv,evals)
  DO IST=1,NSTATES
    EVALS(IST) = REAL( ZDOTC(NBASIS, V(:,IST),1, HV(:,IST),1) )
  ENDDO

  ! Calculate matrix of residual vector
  DO IST=1,NSTATES
    R(:,IST) = EVALS(IST)*V(:,IST) - HV(:,IST)
    RES_TOL(IST) = SQRT( ZDOTC(NBASIS, R(:,IST),1, R(:,IST),1) )
  ENDDO

  ISTEP = 1
  IS_CONVERGED = .FALSE.
  MAX_DIR = 30
  MACHINE_ZERO = 2.220446049250313D-16
  TOLERANCE = 1.0D-7
  RNORM = 1.D0

  DO WHILE ( (ISTEP <= MAX_DIR) .AND. (.NOT.IS_CONVERGED) )
    !WRITE(*,'(2I8,F18.10)') ISTEP, NCONV, RNORM
    RES_NORM = 1.D0

    ! WHERE(MACHINE_ZERO < RES_TOL) RES_NORM = 1.0_DP/RES_TOL
    !WRITE(*,*) 'RES_NORM:'
    DO IST = 1,NSTATES
      IF(MACHINE_ZERO < RES_TOL(IST)) RES_NORM(IST) = 1.D0/RES_TOL(IST)
      !WRITE(*,*) RES_NORM(IST)
    END DO

    ! Scale the residual vectors
    DO IST=1,NSTATES
      R(:,IST) = RES_NORM(IST)*R(:,IST)
    ENDDO

    ! Apply preconditioner
    DO IST=1,NSTATES
      DO I=1,NBASIS
        R(I,IST) = PREC(I)*R(I,IST)
      ENDDO
    ENDDO

! Construct the reduced hamiltonian. The reduced hamiltonian has dimensions
!  2nb x 2nb and is constructed by filling in four nb x nb blocks one at a time:
! __ 
!|  |
!| <v|H|v>   <v|H|r>  |
!    h_mat = |  |
!| *******   <r|H|r>  | 
!|__|

    DO I=1,NSTATES
      CALL APPLY_HAM(R(:,I), HR(:,I), NBASIS, IK, RHOE, NNR)
    ENDDO

    IF(ISTEP == 1) THEN
      CALL ZGEMM('C','N',NSTATES,NSTATES,NBASIS, Z_ONE,V,NBASIS, HV,NBASIS, Z_ZERO,CMAT,NSTATES)
      H_MAT(1:NSTATES,1:NSTATES) = CMAT
    ELSE
      H_MAT(1:NSTATES,1:NSTATES) = Z_ZERO
      DO IST = 1,NSTATES
        H_MAT(IST,IST) = CMPLX(EVALS(IST),0.D0)
      ENDDO
    ENDIF
    ! <v|H|r> --> cmat
    CALL ZGEMM('C','N',NSTATES,NSTATES,NBASIS, Z_ONE,V,NBASIS, HR,NBASIS, Z_ZERO,CMAT,NSTATES)
    H_MAT(1:NSTATES,NSTATES+1:2*NSTATES) = CMAT
    CALL ZGEMM('C','N',NSTATES,NSTATES,NBASIS, Z_ONE,HR,NBASIS, V,NBASIS, Z_ZERO,CMAT,NSTATES)
    H_MAT(NSTATES+1:2*NSTATES,1:NSTATES) = CMAT
    ! <r|H|r> --> cmat
    CALL ZGEMM('C','N',NSTATES,NSTATES,NBASIS, Z_ONE,R,NBASIS, HR,NBASIS, Z_ZERO,CMAT,NSTATES)
    H_MAT(NSTATES+1:2*NSTATES,NSTATES+1:2*NSTATES) = CMAT

! Construct the reduced overlap matrix which has dimenstions 2nb x 2nb
!   and is constructed by filling in four nb x nb blocks one at a time:
! _   _ 
!|     |
!|  <v|v>   <v|r>  |
!    o_mat = |     |
!|  *****   <r|r>  | 
!|_   _|

    O_MAT(1:NSTATES,1:NSTATES) = Z_ZERO
    DO IST = 1,NSTATES
      O_MAT(IST,IST) = Z_ONE
    END DO
    ! <v|r> --> cmat
    CALL ZGEMM('C','N',NSTATES,NSTATES,NBASIS, Z_ONE,V,NBASIS, R,NBASIS, Z_ZERO,CMAT,NSTATES)
    O_MAT(1:NSTATES,NSTATES+1:2*NSTATES) = CMAT
    CALL ZGEMM('C','N',NSTATES,NSTATES,NBASIS, Z_ONE,R,NBASIS, V,NBASIS, Z_ZERO,CMAT,NSTATES)
    O_MAT(NSTATES+1:2*NSTATES,1:NSTATES) = CMAT
    ! <r|r> --> cmat
    CALL ZGEMM('C','N',NSTATES,NSTATES,NBASIS, Z_ONE,R,NBASIS, R,NBASIS, Z_ZERO,CMAT,NSTATES)
    O_MAT(NSTATES+1:2*NSTATES,NSTATES+1:2*NSTATES) = CMAT

    !CALL EIG_ZHEGV(H_MAT,O_MAT,EVALS_RED)
    CALL EIG_ZHEGV_EVAL_F90(H_MAT,2*NSTATES, O_MAT,2*NSTATES, EVALS_RED, EVEC,2*NSTATES, 2*NSTATES)
    !CALL EIG_ZHEGV(H_MAT,O_MAT,EVALS_RED,2*NSTATES)

    !WRITE(*,*) 'REDUCED EVALS = '
    !DO I=1,2*NSTATES
    !  WRITE(*,*) EVALS_RED(I)
    !ENDDO

    EVALS = EVALS_RED(1:NSTATES)
    CMAT = EVEC(1:NSTATES,1:NSTATES)
    ! V*CMAT --> V
    CALL ZGEMM('N','N',NBASIS,NSTATES,NSTATES, Z_ONE,V,NBASIS, CMAT,NSTATES, Z_ZERO,XTEMP,NBASIS)
    V = XTEMP
    ! HV = HV*CMAT
    CALL ZGEMM('N','N',NBASIS,NSTATES,NSTATES, Z_ONE,HV,NBASIS, CMAT,NSTATES, Z_ZERO,XTEMP,NBASIS)
    HV = XTEMP
    !
    CMAT = EVEC(NSTATES+1:2*NSTATES,1:NSTATES)
    ! V = V + R*CMAT
    CALL ZGEMM('N','N',NBASIS,NSTATES,NSTATES, Z_ONE,R,NBASIS, CMAT,NSTATES, Z_ONE,V,NBASIS)
    ! HV = HV + HR*CMAT
    CALL ZGEMM('N','N',NBASIS,NSTATES,NSTATES, Z_ONE,HR,NBASIS, CMAT,NSTATES, Z_ONE,HV,NBASIS)

    ! Calculate matrix of residual vector
    DO IST=1,NSTATES
      R(:,IST) = EVALS(IST)*V(:,IST) - HV(:,IST)
      RES_TOL(IST) = SQRT( ZDOTC(NBASIS, R(:,IST),1, R(:,IST),1) )
      !WRITE(*,'(1X,I5,2F18.10)') IST, EVALS(IST), RES_TOL(IST)
    ENDDO
    
    IS_CONVERGED = .TRUE.
    DO IST = 1,NSTATES
      IS_CONVERGED = (IS_CONVERGED .AND. (RES_TOL(IST) < TOLERANCE) )
    END DO
    ISTEP = ISTEP + 1
    RNORM = SUM(RES_TOL)/REAL(NSTATES, kind=8)
  END DO

  !rnorm = sum(res_tol)/real(nstates,8)

  !DO IST=1,NSTATES
  !  WRITE(*,'(1X,I5,2F18.10)') IST, EVALS(IST), RES_TOL(IST)
  !ENDDO
  WRITE(*,*) 'END OF DAVIDSON ITERATION: RNORM = ', RNORM
  
  DEALLOCATE(RES_TOL)
  DEALLOCATE(RES_NORM)
  DEALLOCATE(CMAT)
  DEALLOCATE(H_MAT)
  DEALLOCATE(O_MAT)
  DEALLOCATE(EVEC)
  DEALLOCATE(EVALS_RED)
  DEALLOCATE(HV)
  DEALLOCATE(R)
  DEALLOCATE(HR)
  DEALLOCATE(XTEMP)
END SUBROUTINE


!---------------------------------------------------
SUBROUTINE EIG_ZHEGV_EVAL_F90(A,LDA, B,LDB, EVAL, EVEC,LDE, N)
!---------------------------------------------------
  IMPLICIT NONE
  ! ARGUMENTS
  INTEGER :: LDA,LDB,LDE,N
  COMPLEX(8) :: A(LDA,N)
  COMPLEX(8) :: B(LDB,N)
  COMPLEX(8) :: EVEC(LDE,N)
  REAL(8) :: EVAL(N)
  ! LOCAL
  REAL(8), PARAMETER :: SMALL=2.220446049250313D-16
  COMPLEX(8), PARAMETER :: Z_ZERO=(0.D0,0.D0), Z_ONE=(1.D0,0.D0)
  INTEGER :: LWORK, LRWORK, LIWORK, INFO, I, NN
  COMPLEX(8), ALLOCATABLE :: WORK(:)
  REAL(8), ALLOCATABLE :: RWORK(:)
  INTEGER, ALLOCATABLE :: IWORK(:)
  REAL(8) :: SCAL

  LWORK = N*N + 2*N
  LRWORK = 2*N*N + 5*N + 1
  LIWORK = 5*N + 3

  ALLOCATE(WORK(LWORK))
  ALLOCATE(RWORK(LRWORK))
  ALLOCATE(IWORK(LIWORK))

  ! DIAGONALIZE B
  CALL ZHEEVD('V','U',N, B,LDB, EVAL, WORK,LWORK, RWORK,LRWORK, IWORK,LIWORK, INFO)
  IF(INFO /= 0) THEN
    WRITE(*,'(1X,A,I4)') 'ERROR CALLING ZHEEVD IN EIG_ZHEGV_F90 : INFO = ', INFO
    STOP
  ENDIF

  NN = 0
  DO I=1,N
    IF( EVAL(I) > SMALL ) THEN
      NN = NN + 1
      SCAL = 1.D0/SQRT(EVAL(I))
      CALL ZDSCAL(N, SCAL, B(:,I),1)
    ENDIF
  ENDDO
  IF(NN < N) THEN
    WRITE(*,'(1X,A,I4)') 'WARNING: NUMBER OF LINEARLY INDEPENDENT VECTORS = ', NN
    WRITE(*,'(1X,A,I4)') '       WHILE SIZE OF THE PROBLEM = ', N
  ENDIF

  ! TRANSFORM A:
  ! A <-- EVEC(B)* A EVEC(B)
  CALL ZGEMM('N','N', N,N,N, Z_ONE,A,LDA, B,LDB, Z_ZERO,EVEC,LDE)
  CALL ZGEMM('C','N', N,N,N, Z_ONE,B,LDB, EVEC,LDE, Z_ZERO,A,LDA)

  ! DIAGONALIZE TRANSFORMED A
  CALL ZHEEVD('V','U',N, A,LDA, EVAL, WORK,LWORK, RWORK,LRWORK, IWORK,LIWORK, INFO)
  IF(INFO /= 0) THEN
    WRITE(*,'(1X,A,I4)') 'ERROR CALLING ZHEEVD IN EIG_ZHEEVD_F90 : INFO = ', INFO
    STOP
  ENDIF

  ! BACK TRANSFORM EIGENVECTORS
  CALL ZGEMM('N','N', N,N,N, Z_ONE,B,LDB, A,LDA, Z_ZERO,EVEC,LDE)

  DEALLOCATE(WORK)
  DEALLOCATE(RWORK)
  DEALLOCATE(IWORK)
END SUBROUTINE
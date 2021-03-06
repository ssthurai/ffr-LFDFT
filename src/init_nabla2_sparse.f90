!!>
!!> \section{Subroutine \texttt{init_nabla2_sparse()}}
!!>
!!> This subroutines initialize sparse Laplacian matrix elements in compressed sparse
!!> column format.
!!> There is code is derived by learning the structure of matrix which is quite regular
!!> compared to sparse matrices which are found in other application. Especially, the
!!> array sizes for CSR (or CSR, because the matrix is symmetric), namely:
!!> \texttt{nzval}, \texttt{rowval}, and \texttt{colptr} are known.
!!>
SUBROUTINE init_nabla2_sparse()

  USE m_LF3d, ONLY : NN => LF3d_NN, &
                     D2jl_x => LF3d_D2jl_x, &
                     D2jl_y => LF3d_D2jl_y, &
                     D2jl_z => LF3d_D2jl_z
  USE m_nabla2_sparse, ONLY : nzval => nabla2_nzval, &
                              rowval => nabla2_rowval, &
                              colptr => nabla2_colptr
  IMPLICIT NONE 
  
  INTEGER :: Nx, Ny, Nz
  INTEGER :: Npoints, nnzc, NNZ
  INTEGER, ALLOCATABLE :: rowGbl_x_orig(:), rowGbl_y_orig(:), rowGbl_z_orig(:)
  INTEGER :: ix, iy, iz, ip
  INTEGER :: yy, colLoc_x, colLoc_y, colLoc_z, izz
  INTEGER :: colGbl, ii
  INTEGER, ALLOCATABLE :: iwork(:)
  INTEGER :: nwork

  Nx = NN(1)
  Ny = NN(2)
  Nz = NN(3)
  Npoints = Nx*Ny*Nz

!!> This is number of nonzeros per column.
!!>
  nnzc = Nx + Ny + Nz - 2

!!> This is total number of nonzeros.
!!>
  NNZ  = nnzc*Npoints

!!> Allocate the arrays for CSR/CSC format
!!>
  ALLOCATE( rowval(NNZ) )
  ALLOCATE( nzval(NNZ) )
  ALLOCATE( colptr(Npoints+1) )

!!> Display some messages:
!!>
  WRITE(*,*)
  WRITE(*,*) 'Initializing nabla2_sparse'
  WRITE(*,'(1x,A,ES12.3,A)') 'Memory required for init_nabla2_sparse:', &
             ( NNZ*8d0 + (NNZ + Npoints + 1)*4.d0 )/1024.d0/1024.d0/1024.d0, &
             ' GB'
  flush(6)

!!>
!!> Initialize \texttt{rowGbl} pattern for x, y, and z components.
!!> For each \texttt{colGbl}, these arrays will vary according to some patterns.
!!>
  ALLOCATE( rowGbl_x_orig(Nx) )
  ALLOCATE( rowGbl_y_orig(Ny) )
  ALLOCATE( rowGbl_z_orig(Nz) )
  !
  rowGbl_x_orig(1) = 1
  DO ix = 2,Nx
    rowGbl_x_orig(ix) = rowGbl_x_orig(ix-1) + Ny*Nz
  ENDDO 
  !
  rowGbl_y_orig(1) = 1
  DO iy = 2,Ny
    rowGbl_y_orig(iy) = rowGbl_y_orig(iy-1) + Nz
  ENDDO 
  !
  DO iz = 1,Nz
    rowGbl_z_orig(iz) = iz
  ENDDO 

!!> Initialize counter for diagonal elements (should be the same as \texttt{Npoints}).
!!>
  ip = 0

!!> Loop over column to determine rowval and nzval.
!!> Because the matrix we are dealing with is symmetric, we can
!!> interchange index for row and column.
!!>
  DO colGbl = 1,Npoints

!!> Determine local column index for x, y, and z components
!!>
    colLoc_x = ceiling( real(colGbl)/(Ny*Nz) )
    !
    yy = colGbl - (colLoc_x - 1)*Ny*Nz
    colLoc_y = ceiling( real(yy)/Nz )
    !
    izz = ceiling( real(colGbl)/Nz )
    colLoc_z = colGbl - (izz-1)*Nz

!!> Diagonal element, which is only one element in any column/row,
!!> is calculated as sum of the corresponding local matrix elements in x, y, and z
!!>
    ip = ip + 1
    rowval(ip) = colGbl
    nzval(ip) = D2jl_x(colLoc_x,colLoc_x) + D2jl_y(colLoc_y,colLoc_y) + D2jl_z(colLoc_z,colLoc_z)

!!> Non-diagonal elements.
!!>
    DO ix = 1,Nx
      IF ( ix /= colLoc_x ) THEN 
        ip = ip + 1
        rowval(ip) = rowGbl_x_orig(ix) + colGbl - 1 - (colLoc_x - 1)*Ny*Nz
        nzval(ip) = D2jl_x(ix,colLoc_x)
      ENDIF 
    ENDDO 
    !
    DO iy = 1,Ny
      IF ( iy /= colLoc_y ) THEN 
        ip = ip + 1
        rowval(ip) = rowGbl_y_orig(iy) + colGbl - 1 - (izz-1)*Nz + (colLoc_x - 1)*Ny*Nz
        nzval(ip) = D2jl_y(iy,colLoc_y)
      ENDIF 
    ENDDO 
    !
    DO iz = 1,Nz
      IF ( iz /= colLoc_z ) THEN 
        ip = ip + 1
        rowval(ip) = rowGbl_z_orig(iz) + (izz-1)*Nz
        nzval(ip) = D2jl_z(iz,colLoc_z)
      ENDIF 
    ENDDO 

  ENDDO 

!!> \texttt{colptr} is easier to compute.
!!>
  colptr(1) = 1
  DO ii = 2,Npoints+1
    colptr(ii) = colptr(ii-1) + nnzc
  ENDDO 

  DEALLOCATE( rowGbl_x_orig )
  DEALLOCATE( rowGbl_y_orig )
  DEALLOCATE( rowGbl_z_orig )

!!>
!!> Sort the resulting \texttt{colptr}, this is required for ILU preconditioning.
!!> This is not required for matrix multiplication routine, though.
!!>
! FIXME: Probably we need a way to by pass this sorting step.
!        Alternatively, use matrix-free preconditioner
!
  nwork = max( Npoints+1, 2*(colptr(Npoints+1)-colptr(1)) )
  ALLOCATE( iwork( nwork ) )
  CALL csort( Npoints, nzval, rowval, colptr, iwork, .TRUE. )
  DEALLOCATE( iwork )

  flush(6)

END SUBROUTINE 


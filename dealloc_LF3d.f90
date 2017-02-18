SUBROUTINE dealloc_LF3d( )
  USE m_LF3d

  DEALLOCATE( LF3d_grid_x )
  DEALLOCATE( LF3d_grid_y )
  DEALLOCATE( LF3d_grid_z )

  DEALLOCATE( LF3d_lingrid )
  DEALLOCATE( LF3d_xyz2lin )
  DEALLOCATE( LF3d_lin2xyz )

  DEALLOCATE( LF3d_D1jl_x )
  DEALLOCATE( LF3d_D1jl_y )
  DEALLOCATE( LF3d_D1jl_z )
 
  DEALLOCATE( LF3d_D2jl_x )
  DEALLOCATE( LF3d_D2jl_y )
  DEALLOCATE( LF3d_D2jl_z )

END SUBROUTINE 
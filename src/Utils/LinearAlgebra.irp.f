subroutine ortho_lowdin(overlap,LDA,N,C,LDC,m)
  implicit none
  BEGIN_DOC
  ! Compute C_new=C_old.S^-1/2 canonical orthogonalization.
  !
  ! overlap : overlap matrix 
  !
  ! LDA : leftmost dimension of overlap array
  !
  ! N : Overlap matrix is NxN (array is (LDA,N) )
  !
  ! C : Coefficients of the vectors to orthogonalize. On exit,
  !     orthogonal vectors
  !
  ! LDC : leftmost dimension of C
  !
  ! m : Coefficients matrix is MxN, ( array is (LDC,N) )
  !
  END_DOC
  
  integer, intent(in)            :: LDA, ldc, n, m
  double precision, intent(in)   :: overlap(lda,n)
  double precision, intent(inout) :: C(ldc,n)
  double precision               :: U(ldc,n)
  double precision               :: Vt(lda,n)
  double precision               :: D(n)
  double precision               :: S_half(lda,n)
  double precision,allocatable   :: work(:)
  !DEC$ ATTRIBUTES ALIGN : 64    :: U, Vt, D, work
  integer                        :: info, lwork, i, j, k
  
  double precision,allocatable   :: overlap_tmp(:,:)
  allocate (overlap_tmp(lda,n))
  overlap_tmp = overlap
  
  allocate(work(1))
  lwork = -1
  call dgesvd('A','A', n, n, overlap_tmp, lda,                       &
      D, U, ldc, Vt, lda, work, lwork, info)
  lwork = work(1)
  deallocate(work)
  allocate(work(lwork))
  call dgesvd('A','A', n, n, overlap_tmp, lda,                       &
      D, U, ldc, Vt, lda, work, lwork, info)
  deallocate(work,overlap_tmp)
  if (info /= 0) then
    print *,  info, ': SVD failed'
    stop
  endif
  
  !$OMP PARALLEL DEFAULT(NONE) &
  !$OMP SHARED(S_half,U,D,Vt,n,C,m) &
  !$OMP PRIVATE(i,j,k)

  !$OMP DO
  do i=1,n
    if ( D(i) < 1.d-6 ) then
      D(i) = 0.d0
    else
      D(i) = 1.d0/dsqrt(D(i))
    endif
    do j=1,n
      S_half(j,i) = 0.d0
    enddo
  enddo
  !$OMP END DO

  do k=1,n
    !$OMP DO
    do j=1,n
      do i=1,n
        S_half(i,j) = S_half(i,j) + U(i,k)*D(k)*Vt(k,j)
      enddo
    enddo
    !$OMP END DO NOWAIT
  enddo
  
  !$OMP BARRIER
  !$OMP DO
  do j=1,n
    do i=1,m
      U(i,j) = C(i,j)
    enddo
  enddo
  !$OMP END DO
  
  !$OMP END PARALLEL

  call dgemm('N','N',m,n,n,1.d0,U,size(U,1),S_half,size(S_half,1),0.d0,C,size(C,1))
  
end



subroutine get_pseudo_inverse(A,m,n,C,LDA)
  implicit none
  BEGIN_DOC
  ! Find C = A^-1
  END_DOC
  integer, intent(in)            :: m,n, LDA
  double precision, intent(in)   :: A(LDA,n)
  double precision, intent(out)  :: C(n,m)
  
  double precision, allocatable  :: U(:,:), D(:), Vt(:,:), work(:), A_tmp(:,:)
  integer                        :: info, lwork
  integer                        :: i,j,k
  allocate (D(n),U(m,n),Vt(n,n),work(1),A_tmp(m,n))
  do j=1,n
    do i=1,m
      A_tmp(i,j) = A(i,j)
    enddo
  enddo
  lwork = -1
  call dgesvd('S','A', m, n, A_tmp, m,D,U,m,Vt,n,work,lwork,info)
  if (info /= 0) then
    print *,  info, ': SVD failed'
    stop
  endif
  lwork = work(1)
  deallocate(work)
  allocate(work(lwork))
  call dgesvd('S','A', m, n, A_tmp, m,D,U,m,Vt,n,work,lwork,info)
  if (info /= 0) then
    print *,  info, ': SVD failed'
    stop 1
  endif
  
  do i=1,n
    if (abs(D(i)) > 1.d-6) then
      D(i) = 1.d0/D(i)
    else
      D(i) = 0.d0
    endif
  enddo
  
  C = 0.d0
  do i=1,m
    do j=1,n
      do k=1,n
        C(j,i) += U(i,k) * D(k) * Vt(k,j)
      enddo
    enddo
  enddo
  
  deallocate(U,D,Vt,work,A_tmp)
  
end

subroutine find_rotation(A,LDA,B,m,C,n)
  implicit none
  BEGIN_DOC
  ! Find A.C = B
  END_DOC
  integer, intent(in)            :: m,n, LDA
  double precision, intent(in)   :: A(LDA,n), B(LDA,n)
  double precision, intent(out)  :: C(n,n)
  
  double precision, allocatable  :: A_inv(:,:)
  allocate(A_inv(LDA,n))
  call get_pseudo_inverse(A,m,n,A_inv,LDA)
  
  integer                        :: i,j,k
  call dgemm('N','N',n,n,m,1.d0,A_inv,n,B,LDA,0.d0,C,n)
  deallocate(A_inv)
end


subroutine apply_rotation(A,LDA,R,LDR,B,LDB,m,n)
  implicit none
  BEGIN_DOC
  ! Apply the rotation found by find_rotation
  END_DOC
  double precision, intent(in)   :: R(LDR,n)
  double precision, intent(in)   :: A(LDA,n)
  double precision, intent(out)  :: B(LDB,n)
  integer, intent(in)            :: m,n, LDA, LDB, LDR
  call dgemm('N','N',m,n,n,1.d0,A,LDA,R,LDR,0.d0,B,LDB)
end

subroutine lapack_diagd(eigvalues,eigvectors,H,nmax,n)
  implicit none
  BEGIN_DOC
  ! Diagonalize matrix H
  !
  ! H is untouched between input and ouptut
  !
  ! eigevalues(i) = ith lowest eigenvalue of the H matrix
  !
  ! eigvectors(i,j) = <i|psi_j> where i is the basis function and psi_j is the j th eigenvector
  !
  END_DOC
  integer, intent(in)            :: n,nmax
  double precision, intent(out)  :: eigvectors(nmax,n)
  double precision, intent(out)  :: eigvalues(n)
  double precision, intent(in)   :: H(nmax,n)
  double precision,allocatable   :: eigenvalues(:)
  double precision,allocatable   :: work(:)
  integer         ,allocatable   :: iwork(:)
  double precision,allocatable   :: A(:,:)
  integer                        :: lwork, info, i,j,l,k, liwork

  allocate(A(nmax,n),eigenvalues(n))
! print*,'Diagonalization by jacobi'
! print*,'n = ',n

  A=H
  lwork = 2*n*n + 6*n+ 1
  liwork = 5*n + 3
  allocate (work(lwork),iwork(liwork))

  lwork = -1
  liwork = -1
  call DSYEVD( 'V', 'U', n, A, nmax, eigenvalues, work, lwork, &
    iwork, liwork, info )
  if (info < 0) then
    print *, irp_here, ': DSYEVD: the ',-info,'-th argument had an illegal value'
    stop 2
  endif
  lwork  = int( work( 1 ) )
  liwork = iwork(1)
  deallocate (work,iwork)

  allocate (work(lwork),iwork(liwork))
  call DSYEVD( 'V', 'U', n, A, nmax, eigenvalues, work, lwork, &
    iwork, liwork, info )
  deallocate(work,iwork)

  if (info < 0) then
    print *, irp_here, ': DSYEVD: the ',-info,'-th argument had an illegal value'
    stop 2
  else if( info > 0  ) then
     write(*,*)'DSYEVD Failed'
     stop 1
  end if

  eigvectors = 0.d0
  eigvalues = 0.d0
  do j = 1, n
    eigvalues(j) = eigenvalues(j)
    do i = 1, n
      eigvectors(i,j) = A(i,j)
    enddo
  enddo
  deallocate(A,eigenvalues)
end

subroutine lapack_diag(eigvalues,eigvectors,H,nmax,n)
  implicit none
  BEGIN_DOC
  ! Diagonalize matrix H
  !
  ! H is untouched between input and ouptut
  !
  ! eigevalues(i) = ith lowest eigenvalue of the H matrix
  !
  ! eigvectors(i,j) = <i|psi_j> where i is the basis function and psi_j is the j th eigenvector
  !
  END_DOC
  integer, intent(in)            :: n,nmax
  double precision, intent(out)  :: eigvectors(nmax,n)
  double precision, intent(out)  :: eigvalues(n)
  double precision, intent(in)   :: H(nmax,n)
  double precision,allocatable   :: eigenvalues(:)
  double precision,allocatable   :: work(:)
  double precision,allocatable   :: A(:,:)
  integer                        :: lwork, info, i,j,l,k, liwork

  allocate(A(nmax,n),eigenvalues(n))
! print*,'Diagonalization by jacobi'
! print*,'n = ',n

  A=H
  lwork = 2*n*n + 6*n+ 1
  allocate (work(lwork))

  lwork = -1
  call DSYEV( 'V', 'U', n, A, nmax, eigenvalues, work, lwork, &
    info )
  if (info < 0) then
    print *, irp_here, ': DSYEV: the ',-info,'-th argument had an illegal value'
    stop 2
  endif
  lwork  = int( work( 1 ) )
  deallocate (work)

  allocate (work(lwork))
  call DSYEV( 'V', 'U', n, A, nmax, eigenvalues, work, lwork, &
    info )
  deallocate(work)

  if (info < 0) then
    print *, irp_here, ': DSYEV: the ',-info,'-th argument had an illegal value'
    stop 2
  else if( info > 0  ) then
     write(*,*)'DSYEV Failed'
     stop 1
  end if

  eigvectors = 0.d0
  eigvalues = 0.d0
  do j = 1, n
    eigvalues(j) = eigenvalues(j)
    do i = 1, n
      eigvectors(i,j) = A(i,j)
    enddo
  enddo
  deallocate(A,eigenvalues)
end

subroutine lapack_diag_s2(eigvalues,eigvectors,H,nmax,n)
  implicit none
  BEGIN_DOC
  ! Diagonalize matrix H
  !
  ! H is untouched between input and ouptut
  !
  ! eigevalues(i) = ith lowest eigenvalue of the H matrix
  !
  ! eigvectors(i,j) = <i|psi_j> where i is the basis function and psi_j is the j th eigenvector
  !
  END_DOC
  integer, intent(in)            :: n,nmax
  double precision, intent(out)  :: eigvectors(nmax,n)
  double precision, intent(out)  :: eigvalues(n)
  double precision, intent(in)   :: H(nmax,n)
  double precision,allocatable   :: eigenvalues(:)
  double precision,allocatable   :: work(:)
  double precision,allocatable   :: A(:,:)
  integer                        :: lwork, info, i,j,l,k, liwork

  allocate(A(nmax,n),eigenvalues(n))
! print*,'Diagonalization by jacobi'
! print*,'n = ',n

  A=H
  lwork = 2*n*n + 6*n+ 1
  allocate (work(lwork))

  lwork = -1
  call DSYEV( 'V', 'U', n, A, nmax, eigenvalues, work, lwork, &
    info )
  if (info < 0) then
    print *, irp_here, ': DSYEV: the ',-info,'-th argument had an illegal value'
    stop 2
  endif
  lwork  = int( work( 1 ) )
  deallocate (work)

  allocate (work(lwork))
  call DSYEV( 'V', 'U', n, A, nmax, eigenvalues, work, lwork, &
    info )
  deallocate(work)

  if (info < 0) then
    print *, irp_here, ': DSYEV: the ',-info,'-th argument had an illegal value'
    stop 2
  else if( info > 0  ) then
     write(*,*)'DSYEV Failed'
     stop 1
  end if

  eigvectors = 0.d0
  eigvalues = 0.d0
  do j = 1, n
    eigvalues(j) = eigenvalues(j)
    do i = 1, n
      eigvectors(i,j) = A(i,j)
    enddo
  enddo
  deallocate(A,eigenvalues)
end




subroutine lapack_partial_diag(eigvalues,eigvectors,H,nmax,n,n_st)
  implicit none
  BEGIN_DOC
  ! Diagonalize matrix H
  !
  ! H is untouched between input and ouptut
  !
  ! eigevalues(i) = ith lowest eigenvalue of the H matrix
  !
  ! eigvectors(i,j) = <i|psi_j> where i is the basis function and psi_j is the j th eigenvector
  !
  END_DOC
  integer, intent(in)            :: n,nmax,n_st
  double precision, intent(out)  :: eigvectors(nmax,n)
  double precision, intent(out)  :: eigvalues(n)
  double precision, intent(in)   :: H(nmax,n)
  double precision,allocatable   :: work(:)
  integer         ,allocatable   :: iwork(:), isuppz(:)
  double precision,allocatable   :: A(:,:)
  integer                        :: lwork, info, i,j,l,k,m, liwork

  allocate(A(nmax,n))

  A=H
  lwork = 2*n*n + 6*n+ 1
  liwork = 5*n + 3
  allocate (work(lwork),iwork(liwork),isuppz(2*N_st))

  lwork = -1
  liwork = -1
  call DSYEVR( 'V', 'I', 'U', n, A, nmax, 0.d0, 0.d0, 1, n_st, 1.d-10, m, eigvalues, eigvectors, nmax, isuppz, work, lwork, &
    iwork, liwork, info )
  if (info < 0) then
    print *, irp_here, ': DSYEVR: the ',-info,'-th argument had an illegal value'
    stop 2
  endif
  lwork  = int( work( 1 ) )
  liwork = iwork(1)
  deallocate (work,iwork)

  allocate (work(lwork),iwork(liwork))
  call DSYEVR( 'V', 'I', 'U', n, A, nmax, 0.d0, 0.d0, 1, n_st, 1.d-10, m, eigvalues, eigvectors, nmax, isuppz, work, lwork, &
    iwork, liwork, info )
  deallocate(work,iwork)

  if (info < 0) then
    print *, irp_here, ': DSYEVR: the ',-info,'-th argument had an illegal value'
    stop 2
  else if( info > 0  ) then
     write(*,*)'DSYEVR Failed'
     stop 1
  end if

  deallocate(A)
end


subroutine set_zero_extra_diag(i1,i2,matrix,lda,m)
 implicit none
 integer, intent(in) :: i1,i2,lda,m
 double precision, intent(inout) :: matrix(lda,m)
 integer :: i,j
 do j=i1,i2
  do i = 1,i1-1
   matrix(i,j) = 0.d0
   matrix(j,i) = 0.d0
  enddo
 enddo

 do i = i2,i1
  do j=i2+1,m
   matrix(i,j) = 0.d0
   matrix(j,i) = 0.d0
  enddo
 enddo


end




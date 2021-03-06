BEGIN_PROVIDER [ integer, ao_num_align ]
   implicit none
   
   BEGIN_DOC
   ! Number of atomic orbitals align
   END_DOC
   
   integer                        :: align_double
   ao_num_align = align_double(ao_num)
END_PROVIDER 

 BEGIN_PROVIDER [ integer, ao_prim_num_max ]
&BEGIN_PROVIDER [ integer, ao_prim_num_max_align ]
 implicit none
 ao_prim_num_max = 0
 PROVIDE ezfio_filename
 call ezfio_get_ao_basis_ao_prim_num_max(ao_prim_num_max)
 integer :: align_double
 ao_prim_num_max_align = align_double(ao_prim_num_max)
 END_PROVIDER

BEGIN_PROVIDER [ double precision, ao_coef_normalized, (ao_num_align,ao_prim_num_max) ]
  implicit none
  BEGIN_DOC
  ! Coefficients including the AO normalization
  END_DOC
  double precision               :: norm, norm2,overlap_x,overlap_y,overlap_z,C_A(3)
  integer                        :: l, powA(3), nz
  integer                        :: i,j
  nz=100
  C_A(1) = 0.d0
  C_A(2) = 0.d0
  C_A(3) = 0.d0
  do i=1,ao_num
    powA(1) = ao_power(i,1)
    powA(2) = ao_power(i,2)
    powA(3) = ao_power(i,3)
    do j=1,ao_prim_num(i)
      call overlap_gaussian_xyz(C_A,C_A,ao_expo(i,j),ao_expo(i,j),powA,powA,overlap_x,overlap_y,overlap_z,norm,nz)
      ao_coef_normalized(i,j) = ao_coef(i,j)/sqrt(norm)
    enddo
  enddo
END_PROVIDER

 BEGIN_PROVIDER [ double precision, ao_coef_normalized_ordered, (ao_num_align,ao_prim_num_max) ]
&BEGIN_PROVIDER [ double precision, ao_expo_ordered, (ao_num_align,ao_prim_num_max) ]
   implicit none
   BEGIN_DOC
   ! Sorted primitives to accelerate 4 index MO transformation
   END_DOC
   
   integer                        :: iorder(ao_prim_num_max)
   double precision               :: d(ao_prim_num_max,2)
   integer                        :: i,j
   do i=1,ao_num
     do j=1,ao_prim_num(i)
       iorder(j) = j
       d(j,1) = ao_expo(i,j)
       d(j,2) = ao_coef_normalized(i,j)
     enddo
     call dsort(d(1,1),iorder,ao_prim_num(i))
     call dset_order(d(1,2),iorder,ao_prim_num(i))
     do j=1,ao_prim_num(i)
       ao_expo_ordered(i,j) = d(j,1)
       ao_coef_normalized_ordered(i,j) = d(j,2)
     enddo
   enddo
END_PROVIDER


BEGIN_PROVIDER [ double precision, ao_coef_normalized_ordered_transp, (ao_prim_num_max_align,ao_num) ]
  implicit none
  BEGIN_DOC
  ! Transposed ao_coef_normalized_ordered
  END_DOC
  integer                        :: i,j
  do j=1, ao_num
    do i=1, ao_prim_num_max
      ao_coef_normalized_ordered_transp(i,j) = ao_coef_normalized_ordered(j,i)
    enddo
  enddo
  
END_PROVIDER

BEGIN_PROVIDER [ double precision, ao_expo_ordered_transp, (ao_prim_num_max_align,ao_num) ]
  implicit none
  BEGIN_DOC
  ! Transposed ao_expo_ordered
  END_DOC
  integer                        :: i,j
  do j=1, ao_num
    do i=1, ao_prim_num_max
      ao_expo_ordered_transp(i,j) = ao_expo_ordered(j,i)
    enddo
  enddo
  
END_PROVIDER

 BEGIN_PROVIDER [ integer, ao_l, (ao_num) ]
&BEGIN_PROVIDER [ character*(128), ao_l_char, (ao_num) ]
 implicit none
 BEGIN_DOC
! ao_l = l value of the AO: a+b+c in x^a y^b z^c
 END_DOC
 integer :: i
 do i=1,ao_num
   ao_l(i) = ao_power(i,1) + ao_power(i,2) + ao_power(i,3) 
   ao_l_char(i) = l_to_charater(ao_l(i))
 enddo
END_PROVIDER

BEGIN_PROVIDER [ integer, ao_prim_num_max_align ]
 implicit none
 BEGIN_DOC
! Number of primitives per atomic orbital aligned
 END_DOC

 integer :: align_double
 ao_prim_num_max_align = align_double(ao_prim_num_max)
END_PROVIDER


BEGIN_PROVIDER [ character*(128), l_to_charater, (0:4)]
 BEGIN_DOC
 ! character corresponding to the "L" value of an AO orbital
 END_DOC
 implicit none
 l_to_charater(0)='S'
 l_to_charater(1)='P'
 l_to_charater(2)='D'
 l_to_charater(3)='F'
 l_to_charater(4)='G'
END_PROVIDER

 BEGIN_PROVIDER [ integer, Nucl_N_Aos, (nucl_num)]
&BEGIN_PROVIDER [ integer, N_AOs_max ]
 implicit none
 integer :: i
 BEGIN_DOC
 ! Number of AOs per atom
 END_DOC
 Nucl_N_Aos = 0
 do i = 1, ao_num
  Nucl_N_Aos(ao_nucl(i)) +=1
 enddo
 N_AOs_max = maxval(Nucl_N_Aos)
END_PROVIDER

 BEGIN_PROVIDER [ integer, Nucl_Aos, (nucl_num,N_AOs_max)]
 implicit none
 BEGIN_DOC
 ! List of AOs attached on each atom
 END_DOC
 integer :: i
 integer, allocatable :: nucl_tmp(:)
 allocate(nucl_tmp(nucl_num))
 nucl_tmp = 0
 Nucl_Aos = 0
 do i = 1, ao_num
  nucl_tmp(ao_nucl(i))+=1
  Nucl_Aos(ao_nucl(i),nucl_tmp(ao_nucl(i))) = i
 enddo
 deallocate(nucl_tmp)
END_PROVIDER


 BEGIN_PROVIDER [ integer, Nucl_list_shell_Aos, (nucl_num,N_AOs_max)]
&BEGIN_PROVIDER [ integer, Nucl_num_shell_Aos, (nucl_num)]
 implicit none
 integer :: i,j,k
 BEGIN_DOC
 ! Index of the shell type Aos and of the corresponding Aos 
 ! Per convention, for P,D,F and G AOs, we take the index 
 ! of the AO with the the corresponding power in the "X" axis
 END_DOC
 do i = 1, nucl_num
  Nucl_num_shell_Aos(i) = 0

  do j = 1, Nucl_N_Aos(i)
   if(ao_l(Nucl_Aos(i,j))==0)then
   ! S type function
   Nucl_num_shell_Aos(i)+=1
   Nucl_list_shell_Aos(i,Nucl_num_shell_Aos(i))=Nucl_Aos(i,j)
   elseif(ao_l(Nucl_Aos(i,j))==1)then
   ! P type function
    if(ao_power(Nucl_Aos(i,j),1)==1)then
     Nucl_num_shell_Aos(i)+=1
     Nucl_list_shell_Aos(i,Nucl_num_shell_Aos(i))=Nucl_Aos(i,j)
    endif
   elseif(ao_l(Nucl_Aos(i,j))==2)then
   ! D type function
    if(ao_power(Nucl_Aos(i,j),1)==2)then
     Nucl_num_shell_Aos(i)+=1
     Nucl_list_shell_Aos(i,Nucl_num_shell_Aos(i))=Nucl_Aos(i,j)
    endif
   elseif(ao_l(Nucl_Aos(i,j))==3)then
   ! F type function
    if(ao_power(Nucl_Aos(i,j),1)==3)then
     Nucl_num_shell_Aos(i)+=1
     Nucl_list_shell_Aos(i,Nucl_num_shell_Aos(i))=Nucl_Aos(i,j)
    endif
   elseif(ao_l(Nucl_Aos(i,j))==4)then
   ! G type function
    if(ao_power(Nucl_Aos(i,j),1)==4)then
     Nucl_num_shell_Aos(i)+=1
     Nucl_list_shell_Aos(i,Nucl_num_shell_Aos(i))=Nucl_Aos(i,j)
    endif
   endif

  enddo
 enddo

END_PROVIDER


BEGIN_PROVIDER [ character*(4), ao_l_char_space, (ao_num) ]
 implicit none
 integer :: i
 character*(4) :: give_ao_character_space
 do i=1,ao_num

  if(ao_l(i)==0)then
  ! S type AO
   give_ao_character_space = 'S   '
  elseif(ao_l(i) == 1)then
  ! P type AO
   if(ao_power(i,1)==1)then
    give_ao_character_space = 'X   '
   elseif(ao_power(i,2) == 1)then
    give_ao_character_space = 'Y   '
   else 
    give_ao_character_space = 'Z   '
   endif
  elseif(ao_l(i) == 2)then
  ! D type AO
   if(ao_power(i,1)==2)then
    give_ao_character_space = 'XX  '
   elseif(ao_power(i,2) == 2)then
    give_ao_character_space = 'YY  '
   elseif(ao_power(i,3) == 2)then
    give_ao_character_space = 'ZZ  '
   elseif(ao_power(i,1) == 1 .and. ao_power(i,2) == 1)then
    give_ao_character_space = 'XY  '
   elseif(ao_power(i,1) == 1 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'XZ  '
   else
    give_ao_character_space = 'YZ  '
   endif
  elseif(ao_l(i) == 3)then
  ! F type AO
   if(ao_power(i,1)==3)then
    give_ao_character_space = 'XXX '
   elseif(ao_power(i,2) == 3)then
    give_ao_character_space = 'YYY '
   elseif(ao_power(i,3) == 3)then
    give_ao_character_space = 'ZZZ '
   elseif(ao_power(i,1) == 2 .and. ao_power(i,2) == 1)then
    give_ao_character_space = 'XXY '
   elseif(ao_power(i,1) == 2 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'XXZ '
   elseif(ao_power(i,2) == 2 .and. ao_power(i,1) == 1)then
    give_ao_character_space = 'YYX '
   elseif(ao_power(i,2) == 2 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'YYZ '
   elseif(ao_power(i,3) == 2 .and. ao_power(i,1) == 1)then
    give_ao_character_space = 'ZZX '
   elseif(ao_power(i,3) == 2 .and. ao_power(i,2) == 1)then
    give_ao_character_space = 'ZZY '
   elseif(ao_power(i,3) == 1 .and. ao_power(i,2) == 1 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'XYZ '
   endif
  elseif(ao_l(i) == 4)then
  ! G type AO
   if(ao_power(i,1)==4)then
    give_ao_character_space = 'XXXX'
   elseif(ao_power(i,2) == 4)then
    give_ao_character_space = 'YYYY'
   elseif(ao_power(i,3) == 4)then
    give_ao_character_space = 'ZZZZ'
   elseif(ao_power(i,1) == 3 .and. ao_power(i,2) == 1)then
    give_ao_character_space = 'XXXY'
   elseif(ao_power(i,1) == 3 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'XXXZ'
   elseif(ao_power(i,2) == 3 .and. ao_power(i,1) == 1)then
    give_ao_character_space = 'YYYX'
   elseif(ao_power(i,2) == 3 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'YYYZ'
   elseif(ao_power(i,3) == 3 .and. ao_power(i,1) == 1)then
    give_ao_character_space = 'ZZZX'
   elseif(ao_power(i,3) == 3 .and. ao_power(i,2) == 1)then
    give_ao_character_space = 'ZZZY'
   elseif(ao_power(i,1) == 2 .and. ao_power(i,2) == 2)then
    give_ao_character_space = 'XXYY'
   elseif(ao_power(i,2) == 2 .and. ao_power(i,3) == 2)then
    give_ao_character_space = 'YYZZ'
   elseif(ao_power(i,1) == 2 .and. ao_power(i,2) == 1 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'XXYZ'
   elseif(ao_power(i,2) == 2 .and. ao_power(i,1) == 1 .and. ao_power(i,3) == 1)then
    give_ao_character_space = 'YYXZ'
   elseif(ao_power(i,3) == 2 .and. ao_power(i,1) == 1 .and. ao_power(i,2) == 1)then
    give_ao_character_space = 'ZZXY'
   endif
  endif
   ao_l_char_space(i) = give_ao_character_space
 enddo
END_PROVIDER

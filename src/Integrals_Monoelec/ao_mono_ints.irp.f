BEGIN_PROVIDER [ double precision, ao_mono_elec_integral,(ao_num_align,ao_num)]
  implicit none
  integer :: i,j,n,l
  BEGIN_DOC
 ! array of the mono electronic hamiltonian on the AOs basis
 ! : sum of the kinetic and nuclear electronic potential 
  END_DOC
  do j = 1, ao_num
   do i = 1, ao_num
    ao_mono_elec_integral(i,j) = ao_nucl_elec_integral(i,j) + ao_kinetic_integral(i,j) + ao_pseudo_integral(i,j)
   enddo
  enddo
END_PROVIDER


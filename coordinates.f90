program coordinates
integer i,j
integer natoms
character*4, allocatable, dimension(:) :: spcs
character*4, parameter :: vasp(*) =['O   ','Si  ','H   ','Al  ','Na  ']
integer :: count_atoms(5)
real, dimension(:,:), allocatable :: nspcs

open(100,file='coordinates.dump',status='old')
open(200,file='cartesian.vasp',status='unknown')
open(300,file='number_atoms.vasp',status='unknown')

read(*,*) natoms
allocate(spcs(natoms)) ; allocate(nspcs(natoms,3))


do i=1,natoms
    read(100,*) (nspcs(i,j),j=1,3),spcs(i)
end do

count_atoms(:)=0
do i=1,5
    !write(*,*) vasp(i) 
    do j=1,natoms
        if (spcs(j)==vasp(i)) then
            count_atoms(i) = count_atoms(i)+1
            write(200,*) nspcs(j,:)
        end if  
    end do
end do

write(300,*) count_atoms(:)

end program coordinates

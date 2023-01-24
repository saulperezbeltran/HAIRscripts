#!/bin/bash
##NECESSARY JOB SPECIFICATIONS
#SBATCH --job-name=SiO2_1_1      #Set the job name to "JobExample2"
#SBATCH --time=96:00:00               #Set the wall clock limit to 6hr and 30min
#SBATCH --nodes=1                    #Request 1 node
#SBATCH --ntasks-per-node=48          #Request 8 tasks/cores per node
#SBATCH --mem=360G                     #Request 8GB per node
#SBATCH --output=Example2Out.%j      #Send stdout/err to "Example2Out.[jobID]"

##OPTIONAL JOB SPECIFICATIONS
#SBATCH --mail-type=ALL              #Send email on all job events
#SBATCH --mail-user=adabrazosterra@gmail.com    #Send all emails to email_address

#PATHS
cwd=$(pwd)
DE1500K=$cwd/DE1500K

VaspTwoLammps() {
    dos2unix POSCAR.vasp
    vasp2lammps POSCAR.vasp
    sed -i "9,10 d" POSCAR.lmpdat
    sed -i "11,15 d" POSCAR.lmpdat
    sed -i "11 a 1   15.9990 # O"  POSCAR.lmpdat
    sed -i "12 a 2   28.0600 # Si" POSCAR.lmpdat
    sed -i "13 a 3    1.0080 # H"  POSCAR.lmpdat
    sed -i "14 a 4   26.9820 # Al" POSCAR.lmpdat
    sed -i "15 a 5   22.9898 # Na" POSCAR.lmpdat
    sed -i "16 a \              "  POSCAR.lmpdat
    sed -i "11 d" POSCAR.lmpdat
}

LoadLammps() {
    echo "Loading Lammps..."
    module purge 
    module load GCC/8.3.0  OpenMPI/3.1.4
    module load iccifort/2019.5.281  impi/2018.5.288
    module load LAMMPS/3Mar2020-Python-3.7.4-kokkos
    mpirun -n 16 lmp -in *.lmp | tee output

}

LoadVasp() {
    echo "Loading Vasp"
    module purge
    module load intel/2020a
    module load vasp/5.4.4.pl2
    mpirun vasp_gam | tee output

}

GetLastFrameL2V() {
    n=$(grep -n "ITEM: TIMESTEP" positions.dump | tail -1 | cut -d":" -f1)
    sed -n "$n,$ p" positions.dump > LastFrame.dump
    n=$(grep -nr "Loop time" output | tail -1 | cut -d":" -f1); let n=n-1
    cella=$(sed -n "$n p" output | awk '{ print $6}')
    cellb=$(sed -n "$n p" output | awk '{ print $7}')
    cellc=$(sed -n "$n p" output | awk '{ print $8}')

cat > header << EOF
VaspInput
1.0
$cella 0.0 0.0
0.0 $cellb 0.0
0.0 0.0 $cellc
O Si H Al Na
EOF

    sed -n "10,$ p" LastFrame.dump | awk '{ print $3,$4,$5,$7 }' > coordinates.dump
    #
    natoms=$(sed -n "4p" LastFrame.dump)
    gfortran $cwd/coordinates.f90 -o ./coordinates.out
    echo -e $natoms | ./coordinates.out
    sed -i "$ a Cartesian" number_atoms.vasp  
    cat header number_atoms.vasp cartesian.vasp > CONTCAR.vasp
    rm header number_atoms.vasp coordinates.dump coordinates.out cartesian.vasp
}


#DYNAMIC EQUILIBRATION @ 1500 K
rm -fr   $cwd/01_Annealing
echo "Cycle # 1"

echo "Vasp Step"
mkdir -p $cwd/01_Annealing/1-cycle/00_AIMD
cd $cwd/01_Annealing/1-cycle/00_AIMD
cp $cwd/00_DynamicEquilibration/8-cycle/01_AIMD/CONTCAR POSCAR
cp $DE1500K/{INCAR,KPOINTS,POTCAR} .
LoadVasp

echo "ReaxFF step"
mkdir -p $cwd/01_Annealing/1-cycle/00_reaxFF
cd $cwd/01_Annealing/1-cycle/00_reaxFF
cp $cwd/01_Annealing/1-cycle/00_AIMD/CONTCAR POSCAR.vasp
VaspTwoLammps POSCAR.vasp
cp $DE1500K/{in.lmp,2014-Aluminosilicates.reaxff} .
LoadLammps
GetLastFrameL2V

echo "Vasp Step"
mkdir -p $cwd/01_Annealing/1-cycle/01_AIMD
cp CONTCAR.vasp $cwd/01_Annealing/1-cycle/01_AIMD/POSCAR
cd $cwd/01_Annealing/1-cycle/01_AIMD
cp $DE1500K/{INCAR,KPOINTS,POTCAR} .
LoadVasp

for i in $(seq 2 1 30)
do
    echo "Cycle # $i"
    echo "ReaxFF step"     
    mkdir -p $cwd/01_Annealing/$i-cycle/00_reaxFF
    cd $cwd/01_Annealing/$i-cycle/00_reaxFF
    let h=i-1
    cp $cwd/01_Annealing/$h-cycle/01_AIMD/CONTCAR POSCAR.vasp
    VaspTwoLammps POSCAR.vasp
    cp $DE1500K/{in.lmp,2014-Aluminosilicates.reaxff} .
    LoadLammps
    GetLastFrameL2V
    echo "Vasp Step"
    mkdir -p $cwd/01_Annealing/$i-cycle/01_AIMD
    cp CONTCAR.vasp $cwd/01_Annealing/$i-cycle/01_AIMD/POSCAR
    cd $cwd/01_Annealing/$i-cycle/01_AIMD
    cp $DE1500K/{INCAR,KPOINTS,POTCAR} .
    LoadVasp

done

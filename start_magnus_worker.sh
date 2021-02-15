#!/bin/bash -l

#SBATCH --clusters=magnus
#SBATCH --partition=debugq
#SBATCH --ntasks=2
#SBATCH --nodes=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=47G
#SBATCH --time=1:00:00
#SBATCH --account=pawsey0106
#SBATCH --export=NONE
#SBATCH -J dask-worker   # name
#SBATCH -o dask-worker-%J.out

module load singularity

container=$MYSCRATCH/pangeo-custom-20210212.sif
scheduler_file=$MYSCRATCH/scheduler.json

# calculate task memory limit
mempcpu=$((SLURM_MEM_PER_NODE/SLURM_JOB_CPUS_PER_NODE))
SLURM_CPUS_PER_TASK=12
memlim=23500
numworkers=$SLURM_NTASKS

#Set these to have singularity bind data locations
export SINGULARITY_BINDPATH=/group:/group,/scratch:/scratch,/run:/run

#This is needed to setup conda in the container correctly
export SINGULARITYENV_PREPEND_PATH=/srv/conda/envs/notebook/bin:/srv/conda/condabin:/srv/conda/bin
export SINGULARITYENV_XDG_RUNTIME_DIR=""

echo Memory limit is $memlim

echo starting $SLURM_NTASKS workers with $SLURM_CPUS_PER_TASK CPUs each

srun --export=ALL -n $SLURM_NTASKS -c $SLURM_CPUS_PER_TASK \
    singularity exec $container \
    dask-worker --scheduler-file $scheduler_file --nthreads $SLURM_CPUS_PER_TASK --memory-limit ${memlim}M


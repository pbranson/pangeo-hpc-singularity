#!/bin/bash
#SBATCH --account=pawsey0106
#SBATCH --ntasks=10
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=16G
#SBATCH --time=1:00:00
#SBATCH -J acolite-worker   # name
#SBATCH -o acolite-worker-%J.out
#SBATCH -e acolite-worker-%J.err

module load singularity

container=$MYSCRATCH/../pangeo-latest.sif
scheduler_file=$MYSCRATCH/scheduler.json

#Set these to have singularity bind data locations
export SINGULARITY_BINDPATH=/group:/group,/scratch:/scratch,/run:/run,$HOME:$HOME

#This is needed to setup conda in the container correctly
export SINGULARITYENV_PREPEND_PATH=/srv/conda/envs/notebook/bin:/srv/conda/condabin:/srv/conda/bin
export SINGULARITYENV_XDG_RUNTIME_DIR=""

#Override some default dask config specific to stop killed workers running acolite 
export SINGULARITYENV_DASK_DISTRIBUTED__WORKER__MEMORY__PAUSE=False
export SINGULARITYENV_DASK_DISTRIBUTED__WORKER__MEMORY__TERMINATE=False

# calculate task memory limit
mempcpu=$SLURM_MEM_PER_CPU
memlim=$(echo $SLURM_CPUS_PER_TASK*$mempcpu*1.2 | bc)

echo Memory limit is $memlim

echo starting $SLURM_NTASKS workers with $SLURM_CPUS_PER_TASK CPUs each

srun --export=ALL -n $SLURM_NTASKS -c $SLURM_CPUS_PER_TASK \
singularity exec $container \
dask-worker --scheduler-file $scheduler_file --nthreads $SLURM_CPUS_PER_TASK --memory-limit auto  


#!/bin/bash
#SBATCH --ntasks=20
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=10G
#SBATCH --time=0:30:00
#SBATCH -J dask-worker   # name
#SBATCH -o dask-worker-%J.out

module load singularity

container=$SCRATCH1DIR/pangeo-custom-20200724.sif
scheduler_file=$SCRATCH1DIR/scheduler.json

#Set these to have singularity bind data locations
export SINGULARITY_BINDPATH=/apps:/apps,/datasets:/datasets,/scratch1:/scratch1,/flush3:/flush3,/OSM:/OSM,/run:/run,/flush_netapp:/flush_netapp,/datastore:/datastore

#This is needed to setup conda in the container correctly
export SINGULARITYENV_PREPEND_PATH=/srv/conda/envs/notebook/bin:/srv/conda/condabin:/srv/conda/bin

# calculate task memory limit
mempcpu=$SLURM_MEM_PER_CPU
memlim=$(echo $SLURM_CPUS_PER_TASK*$mempcpu*0.98 | bc)

echo Memory limit is $memlim

echo starting $SLURM_NTASKS workers with $SLURM_CPUS_PER_TASK CPUs each

srun --export=ALL -n $SLURM_NTASKS -c $SLURM_CPUS_PER_TASK \
singularity exec $container \
dask-worker --scheduler-file $scheduler_file --nthreads $SLURM_CPUS_PER_TASK --memory-limit ${memlim}M --local-directory $LOCALDIR


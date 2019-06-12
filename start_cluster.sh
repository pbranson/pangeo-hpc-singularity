#!/bin/bash -l

#SBATCH --partition=workq
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --time=16:00:00
#SBATCH --account=pawsey0106
#SBATCH --export=NONE
#SBATCH -J dask   # name
#SBATCH -o dask-%J.out

module load singularity

mkdir $MYSCRATCH/tmp
export TMPDIR=$MYSCRATCH/tmp
export MY_CONTAINER=$MYSCRATCH/tensorflow/keras-pawsey.sif
export SINGULARITY_CACHEDIR=${MYGROUP}/singularity


srun --export=ALL -n 1 -c $SLURM_CPUS_PER_TASK singularity exec --bind $HOME:/run/user \
       --bind /scratch \
       --bind /group \
       $MY_CONTAINER \
       dask-scheduler --scheduler-file $HOME/scheduler.json &

mempcpu=$SLURM_MEM_PER_CPU
memlim=$(echo $SLURM_CPUS_PER_TASK*$mempcpu*0.95 | bc)
numworker=$((SLURM_NTASKS-1))
echo Memory limit is $memlim, numworkers is $numworker

srun --export=ALL -n $numworker -c $SLURM_CPUS_PER_TASK singularity exec --bind $HOME:/run/user \
       --bind /scratch \
       --bind /group \
       $MY_CONTAINER \
       dask-worker --scheduler-file $HOME/scheduler.json \
                   --nthreads $SLURM_CPUS_PER_TASK \
                   --memory-limit ${memlim}M



#!/bin/bash
#SBATCH --account=pawsey0106
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=6g 
#SBATCH --ntasks=1
#SBATCH --time=10:00:00

module load singularity
container=$1 #or hardcode a path e.g. /group/pawsey0106/singularity/pangeo-latest.sif
notebook_dir=$2 #Directory where you want the jupyter lab to start


#Set these to have singularity bind data locations
export SINGULARITY_BINDPATH=/group:/group,/scratch:/scratch,/run:/run,$HOME:$HOME 

#This is needed to setup conda in the container correctly
export SINGULARITYENV_PREPEND_PATH=/srv/conda/envs/notebook/bin:/srv/conda/condabin:/srv/conda/bin
export SINGULARITYENV_XDG_DATA_HOME=$MYGROUP/.local

# FOR SOME REASON CANT ISSUE MULTIPLE srun FROM SINGLE SCRIPT. NEED TO START SCHEDULER WITHIN THE JUPYTER LAB NOW
# Start the scheduler - saving scheduler info to $SCRATCH1DIR/scheduler.json
#scheduler_file=$MYSCRATCH/scheduler.json
#srun -o scheduler-$SLURM_JOBID.out --export=ALL -n 1 -c $SLURM_CPUS_PER_TASK singularity exec $container dask-scheduler --scheduler-file $scheduler_file --idle-timeout 0 &

# Set the port for the SSH tunnel
# This part of the script uses a loop to search for available ports on the node;
# this will allow multiple instances of GUI servers to be run from the same host node
port="8888"
pfound="0"
while [ $port -lt 65535 ] ; do
  check=$( netstat -tuna | awk '{print $4}' | grep ":$port *" )
  if [ "$check" == "" ] ; then
    pfound="1"
    break
  fi
  : $((++port))
done
if [ $pfound -eq 0 ] ; then
  echo "No available communication port found to establish the SSH tunnel."
  echo "Try again later. Exiting."
  exit
fi

srun -o jupyter-$SLURM_JOBID.out --export=ALL -n 1 -N 1 -c $SLURM_CPUS_PER_TASK singularity exec \
    $container \
    jupyter lab --no-browser --ip=0.0.0.0 --notebook-dir=$notebook_dir --port=$port

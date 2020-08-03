#!/bin/bash
#SBATCH --ntasks=2
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=8G
#SBATCH --time=10:00:00

module load singularity
notebook_dir=$1
container=$SCRATCH1DIR/pangeo-custom-20200724.sif
scheduler_file=$SCRATCH1DIR/scheduler.json
JUPYTER_TOKEN=$(uuidgen)

#Set these to have singularity bind data locations
export SINGULARITY_BINDPATH=/apps:/apps,/datasets:/datasets,/scratch1:/scratch1,/flush3:/flush3,/OSM:/OSM,/run:/run,/flush_netapp:/flush_netapp,/datastore:/datastore

#This is needed to setup conda in the container correctly
export SINGULARITYENV_PREPEND_PATH=/srv/conda/envs/notebook/bin:/srv/conda/condabin:/srv/conda/bin

# Start the scheduler - saving scheduler info to $SCRATCH1DIR/scheduler.json
srun --export=ALL -n 1 -N 1 -c $SLURM_CPUS_PER_TASK singularity exec $container dask-scheduler --scheduler-file $scheduler_file --idle-timeout 0 &

LOCALHOST_PORT=8888
PORT=8888

JNHOST=$(hostname)
JNIP=$(hostname -i)

LOGFILE=$SCRATCH1DIR/pangeo_jupyter_log.$(date +%Y%m%dT%H%M%S)

echo "Logging jupyter notebook session on $JNHOST to $LOGFILE"

echo -en "\nStarting jupyter notebook server, please wait a little (up to a few minutes) to let it start. You can follow the file $LOGFILE to check using \n\n tail -F $LOGFILE"

cat << EOF
Run the following command on your desktop or laptop:
    ssh -N -l $USER -L ${LOCALHOST_PORT}:${JNHOST}:$PORT pearcey.hpc.csiro.au
Log in with your Username/Password or SSH keys.
Then open a browser and go to http://localhost:${LOCALHOST_PORT}. The Jupyter web
interface will ask you for a token. Use the following:
    $JUPYTER_TOKEN
Note that anyone to whom you give the token can access (and modify/delete)
files in your PAWSEY spaces, regardless of the file permissions you
have set. SHARE TOKENS RARELY AND WISELY!
To stop the server, press Ctrl-C.
EOF

srun --export=ALL -n 1 -N 1 -c $SLURM_CPUS_PER_TASK singularity exec  \
    $container \
    jupyter lab --no-browser --ip=$JNHOST --notebook-dir=$notebook_dir --NotebookApp.token=$JUPYTER_TOKEN >& $LOGFILE 

#!/bin/bash -l

#SBATCH --partition=workq
##SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=5G
#SBATCH --time=01:00:00
#SBATCH --account=pawsey0106
#SBATCH --export=ALL
#SBATCH -J jupyter   # name
#SBATCH -o jupyter-%J.out

module load singularity

JNHOST=$(hostname)

srun -n 1 -c 4 singularity exec --bind $HOME:/run/user \
       --bind $MYSCRATCH:/scratch \
       --bind $MYGROUP:/group \
       pangeo-notebook.sif \
       dask-scheduler --scheduler-file $HOME/scheduler.json &

# Create trap to kill notebook when user is done
kill_server() {
    if [[ $JNPID != -1 ]]; then
        echo -en "\nKilling Jupyter Notebook Server with PID=$JNPID ... "
        kill $JNPID
        echo "done"
        exit 0
    else
        exit 1
    fi
}

let DASK_PORT=8787
let LOCALHOST_PORT=8888

JNHOST=$(hostname)
JNIP=$(hostname -i)

LOGFILE=$MYSCRATCH/pangeo_jupyter_log.$(date +%Y%m%dT%H%M%S)


echo "Logging jupyter notebook session on $JNHOST to $LOGFILE"


srun -n 1 -c 4 singularity exec --bind $HOME:/run/user \
   --bind $MYSCRATCH:/scratch \
   --bind $MYGROUP:/group \
   pangeo-notebook.sif \
   jupyter lab --no-browser --ip=$JNHOST >& $LOGFILE &

JNPID=$!

echo -en "\nStarting jupyter notebook server, please wait ... "

ELAPSED=0
ADDRESS=

while [[ $ADDRESS != *"${JNHOST}"* ]]; do
    sleep 1
    ELAPSED=$(($ELAPSED+1))
    ADDRESS=$(grep -e '^\[.*\]\s*http://.*:.*/\?token=.*' $LOGFILE | head -n 1 | awk -F'//' '{print $NF}')
    if [[ $ELAPSED -gt 360 ]]; then
        echo -e "something went wrong\n---"
        cat $LOGFILE
        echo "---"
        kill_server
    fi
done

echo -e "done\n---\n"

HOST=$(echo $ADDRESS | awk -F':' ' { print $1 } ')
PORT=$(echo $ADDRESS | awk -F':' ' { print $2 } ' | awk -F'/' ' { print $1 } ')
TOKEN=$(echo $ADDRESS | awk -F'=' ' { print $NF } ')

cat << EOF
Run the following command on your desktop or laptop:
    ssh -N -l $USER -L ${LOCALHOST_PORT}:${JNHOST}:$PORT zeus.pawsey.org.au
Log in with your Username/Password or SSH keys.
Then open a browser and go to http://localhost:${LOCALHOST_PORT}. The Jupyter web
interface will ask you for a token. Use the following:
    $TOKEN
Note that anyone to whom you give the token can access (and modify/delete)
files in your PAWSEY spaces, regardless of the file permissions you
have set. SHARE TOKENS RARELY AND WISELY!
To stop the server, press Ctrl-C.
EOF

# Wait for user kill command
sleep inf




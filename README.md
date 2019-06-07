# pangeo-hpc-singularity

Scripts to run Dask and Jupyter lab on HPC (Pawsey SC Zeus) using SLURM and Singularity.

**NOTE** I would recommend using Shifter if available, the process is quite a bit simpler, see https://github.com/pbranson/pangeo-hpc-shifter

The container is based on the pangeo-notebook image that is curated at https://github.com/pangeo-data/pangeo-stacks. The image has been modified to add some directory paths to be used as bind points for the HPC filesystems. At Pawsey these are the SCRATCH and GROUP filesystems which are linked to the paths /scratch and /group in the container respectively. Because singularity uses an file system overlay approach this all works pretty neatly, including that $HOME folder in the container is mapped automatically to the users home and has the same path (i.e. /home/$USERNAME).

The details of the modifications to the container are published [here](https://www.singularity-hub.org/containers/9672/view) ~~and the resulting container can be pulled from shub://pbranson/simages:pangeo-notebook~~ UPDATE: there is some weird bug in Singularity<3 (discussed [here](https://github.com/sylabs/singularity/issues/1301)) that prevents the container being built correctly on singularity hub (which as of 7/6/2019 is only on Singularity 2.5. So you will have to build the container somewhere you have root access and Singularity>3.

We also need to bind some location to /run/user, not entirely clear to me why that is necessary, but jupyter/traitlets writes some files there and without sudo jupyter wont start correctly. Overlaying a writable folder there makes it work. Note that the jupyter TOKEN gets written to a file there so make sure it is a secure location.

## Building the container
```
sudo singularity build pangeo-notebook.sif Singularity.pangeo-notebook
```
## Running the containers
Two convenience scripts are provided for starting jupyter lab and dask.

### Start Jupyter and Dask Scheduler

`jobid=$(sbatch start_jupyter.sh | grep -o [0-9]*) && tail -F jupyter-$jobid.out`

`start_jupyter.sh` does three things:
 1. Starts an instance of the container running a dask-scheduler
 2. Starts an instance of the container running jupyter lab
 3. Parses the log files to print out a helpful string for tunneling to the port jupyter exposed on the compute node

### Start Dask Workers

`jobid=$(sbatch start_worker.sh | grep -o [0-9]*) && tail -F dask-worker-$jobid.out`

`start_worker.sh` uses the container to start dask workers, using the Slurm environment variables to determine the worker specs and memory. This is important to do otherwise dask starts workers that are based on the node specs rather than the job request. Run `sbatch start_worker.sh` a few times to get more workers or alter the slurm parameters

## Connecting to Jupyter

Assuming you tunneled the port with a command like
`ssh -N -l $USERNAME -L 8888:z106:8888 zeus.pawsey.org.au`

Open the browser to http://localhost:8888/

Connect the dask scheduler with:
```
from dask.distributed import Client
client=Client(address='localhost:8786')
client
```
... and view the dask dashboard at http://localhost:8888/proxy/8787/status


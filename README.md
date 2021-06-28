
This repository provides some boiler plate scripts for running 'pangeo' python ecosystem using singularity containers.

Steps are:

1. Obtain docker image curated at https://github.com/pangeo-data/pangeo-stacks
   ```
   docker pull pangeo/pangeo-notebook
   ```
   The pangeo-notebook has a pretty diverse set of libraries for most cloud, 
   dask, zarr, netCDF, analysis type tasks. 

   - (Optional) Obtain docker image curated at https://github.com/pangeo-data/pangeo-stacks
   If you need to customise, see minimal example in Dockerfile and requirements.txt and description here:

      - (Deprecated) https://github.com/pangeo-data/pangeo-stacks#customize-images-with-the--onbuild-variants

       - (**Use this since 27-07-2020**) https://github.com/pangeo-data/pangeo-docker-images

         Then you would build a custom image along the lines of:
         ```
         make pangeo-notebook
         ```
  
2. Convert docker image to singularity with a command such as:
   ```
   singularity -d build pangeo-latest.sif docker-daemon://pangeo/pangeo-notebook:master
   ```

3. Copy the created ```pangeo-latest.sif``` singularity image to somewhere accessible on the HPC filesystem and edit the ```container=``` and ```scheduler_file=``` variables in the ```start_jupyter.slurm``` and ```start_worker.slurm``` scripts to point to the singularity image and the shared filesystem location to write the scheduler details, respectively.


4. Start the jupyter lab and dask-scheduler, the first parameter is the working path you want to use for jupyter lab:
   ```
   sbatch start_jupyter.slurm $MYGROUP
   ```
   This starts a scheduler and jupyterlab with 2 cores each and 8GB/core memory. These can be edited in the #SBATCH headers, also note you can set the default directory for jupyterlab with the notebook_dir which is the parameter passed to start_jupyter.slurm. 
   
   
5. Start dask-workers (where n is the number of workers you want - these are configures for < 2 hour wall time limit so that they use the `h2` queue):
   ```
   sbatch -n 10 start_worker.slurm
   ```
   also note that this input argument to dask-worker ```--local-directory $LOCALDIR``` tells the worker the path to local disk storage on the node which can be used for spilling data, but not all HPC nodes/centres have attached local storage. Currently this is disabled.
   
   
6. See instruction printed to the slurm-######.out log file for connecting to the jupyter session running on the compute node, something like:
   ```
   ssh -N -l pbranson -L 8888:compute-node123:8888 hpc-login.host.com
   ``` 
   and take note of the randomly generated token printed to the slurm-######.out log file. You will need that to login to Jupyterlab.
   
   
7. To connect to the dask-scheduler from a notebook use the following snippet:
   ```
   import os
   from distributed import Client
   client=Client(scheduler_file=os.environ['MYSCRATCH'] + '/scheduler.json')
   client
   ```  
   
8. View the scheduler bokeh dashboard at http://localhost:8888/proxy/8787/status. This can also be entered into the Jupyterlab dask widget as `/proxy/8787/status`

9. As a little cheat in jupyter lab I open up a terminal and then do 
   ```
   ssh localhost
   ``` 
   to connect to the host running the jupyter container - this gives you access to the slurm job scheduler from that terminal and you can start workers  in there with:

   ```
   sbatch start_worker.slurm
   ```
   
   Also note that the dask worker specifications used in the ```start_worker.slurm``` script are based of the slurm environment variables, so you can alter the worker specification using the ```#SBATCH``` directives:
   
   ```
   #SBATCH --ntasks=20
   #SBATCH --cpus-per-task=2
   #SBATCH --mem-per-cpu=10G
   #SBATCH --time=0:30:00
   ```

   or at the command line when you submit the script:

   ```
   sbatch -n 4 -c 4 --mem-per-cpu=16G start_worker.slurm
   ```
   which would start 4 workers with 4 cores per worker and 16*4 = 64GB memory per dask-worker.

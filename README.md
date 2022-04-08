
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


4. Start the jupyter lab and dask-scheduler, the first parameter is the singularity image file, the second is the working path you want to use for jupyter lab:
   ```
   sbatch start_jupyter.slurm $MYGROUP/../singularity/pangeo-latest.sif $MYGROUP
   ```
   This a jupyterlab with the specification set in the SBATCH directives at the top of the script. These can be edited in the #SBATCH headers, also note you can set the default directory for jupyterlab with the notebook_dir which is the parameter passed to start_jupyter.slurm. 
   
   
5. Start dask-workers (where n is the number of workers you want - these are configures for < 2 hour wall time limit so that they use the `h2` queue):
   ```
   sbatch -n 10 start_worker.slurm
   ```
   also note that this input argument to dask-worker ```--local-directory $LOCALDIR``` tells the worker the path to local disk storage on the node which can be used for spilling data, but not all HPC nodes/centres have attached local storage. Currently this is disabled.
   
   
6. Take a look at the output printed to the jupyter-#####.out log file. Once jupyter has started it should print a message like this:

```
[I 2022-04-08 14:14:43.247 ServerApp] http://z127:8888/lab?token=4698b3901dd7be93cca9d32ae0c94950f4d2e500f7023175
[I 2022-04-08 14:14:43.247 ServerApp]  or http://127.0.0.1:8888/lab?token=4698b3901dd7be93cca9d32ae0c94950f4d2e500f7023175
[I 2022-04-08 14:14:43.247 ServerApp] Use Control-C to stop this server and shut down all kernels (twice to skip confirmation).
[C 2022-04-08 14:14:43.261 ServerApp]

    To access the server, open this file in a browser:
        file:///group/pawsey0106/pbranson/.local/jupyter/runtime/jpserver-28698-open.html
    Or copy and paste one of these URLs:
        **http://z127:8888/lab?token=4698b3901dd7be93cca9d32ae0c94950f4d2e500f7023175**
     or http://127.0.0.1:8888/lab?token=4698b3901dd7be93cca9d32ae0c94950f4d2e500f7023175
```

Take note of the second last line in bold. The "z127" is the node it is running on, the "8888" part is the port, and the bit after token= is the password.

7. Open a second terminal on your local computer and start an ssh tunnel through to the jupyter lab running on the compute node using something like this command:
   ```
   ssh -N -l your_username -L 8888:z127:8888 hpc-login.host.com
   ``` 
 The important part is the the bit immediately following the "-L". The first 8888 is the port on your local computer that is tunnelled via the hpc-login.host.com to node z127 and the second 8888 is the port that jupyter lab is listening on. The second 8888 can change, and port used is what is printed in the the log file described at step 6. You likely will need to adjust this command each time you start a new jupyter lab.

8. Open the browser on your computer and enter into the address bar: `http://localhost:8888` this should open up the login screen for the jupyter lab and request the token printed to the log file at step 6. 
   
9. You may wish to use dask, in which case open a terminal **inside** in jupyter, inside the browser and start a dask scheduler for your session with:
```
dask-scheduler --scheduler-file $scheduler_file --idle-timeout 0 &
````

10. You can then connect to the dask-scheduler from a notebook use the following snippet:
   ```
   import os
   from distributed import Client
   client=Client(scheduler_file=os.environ['MYSCRATCH'] + '/scheduler.json')
   client
   ```  
   
11. View the scheduler bokeh dashboard at http://localhost:8888/proxy/8787/status. This can also be entered into the Jupyterlab dask widget as `/proxy/8787/status`

12. As a little cheat in jupyter lab I open up a terminal and then do 
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

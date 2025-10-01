# Cluster Deployment (Requires Container Installation)

The method we use for cluster deployment was adapted from the [Isaac Lab Cluster
Guide](https://isaac-sim.github.io/IsaacLab/main/source/deployment/cluster.html),
modified to work for the extension. It's recommended to first read through that guide
before proceeding.

Read [this guide](https://arc-user-guide.readthedocs.io/en/latest/) on using the Oxford
ARC/HTC cluster before attempting to use this functionality.

## 1 Installing Apptainer

Run the following on your local machine:

```bash
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt update
sudo apt install -y apptainer
```

## 2 Cluster Configuration

Edit [`docker/cluster/.env.cluster`](/docker/cluster/.env.cluster) to suit your needs.

## 3 Exporting to a Singularity Image

Run the following on your local machine:
```bash
./docker/cluster/cluster_interface.sh push
# Executing push command
# Using suffix: my_extension
# [INFO]: Docker version 28.4.0, and Apptainer version 1.4.3 are tested and compatible.
# INFO:    Starting build...
# ...
```
This may take a while, so give it some time.

## 4 Job Parameters

Edit [`docker/cluster/submit_job_slurm.sh`](/docker/cluster/submit_job_slurm.sh) to suit your needs.

## 5 Submitting a Job

You can submit a job to the cluster directly from your local machine as follows (make
sure the `--headless` flag is enabled!):
```bash
./docker/cluster/cluster_interface.sh job --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# [INFO] Executing job command                                                                                                                                         
# 	Using suffix: my_extension
# 	Job arguments: --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# [INFO] Syncing Isaac Lab code...
# [INFO] Syncing Isaac Lab Extension code...
# [INFO] Executing job script...
# [INFO] Arguments passed to job script --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# Submitted batch job 6068175
```
This will copy over the present contents of Isaac Lab and your extension onto the
cluster in a timestamped "temporary" folder and then start the training job. Make sure
to note the job ID.

All training logs will be neatly saved in a separate "permanent" folder in the cluster,
which you can access during and after training.

## 6 Job Monitoring

To check job status from your local machine:
```bash
./docker/cluster/cluster_interface.sh status
# [INFO] Checking job status for user 'abcd1234' on 'abcd1234@htc-login.arc.ox.ac.uk'...                                                                               
#              JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
#            6068175     short isaac-la abcd1234  R       1:36      1 htc-g026
```

To follow job logs from your local machine:
```bash
./docker/cluster/cluster_interface.sh logs 6068175
# [INFO] Tailing logs for job '6068175' on 'abcd1234@htc-login.arc.ox.ac.uk'...
# ...
```

To cancel a job from your local machine:
```bash
./docker/cluster/cluster_interface.sh cancel 6068175
# [INFO] Cancelling job '6068175' on 'abcd1234@htc-login.arc.ox.ac.uk'...
```

## 7 Copying Logs to Local Machine

To copy logs from the cluster back to the local machine, run the following:
```bash
./docker/cluster/cluster_interface.sh copy
# [INFO] Copying logs from the cluster...
# [INFO] Syncing logs from 'abcd1234@htc-login.arc.ox.ac.uk:/data/engs-robotics-ml/abcd1234/isaac-lab-ext-my_extension/logs/' to '/home/jacques/projects/IsaacLabMyExtension/docker/cluster/../../logs/'...
# ...
# [INFO] Log synchronization complete.
```

If you get an `Operation not permitted`/`Permission Denied` error, then first run the following
on your local machine:
```bash
sudo chown -R $USER:$USER logs/ docs/ data_storage/
```

## 8 Cleaning Up Code

To clean up space on the cluster, you can delete all timestamped "temporary" folders by
running the following on your local machine:
```bash
./docker/cluster/cluster_interface.sh cleanup
# [INFO] Executing cleanup command
# [INFO] Deleting directories matching 'isaac-lab-ext-my_extension_*' in '/data/engs-robotics-ml/abcd1234' on 'abcd1234@htc-login.arc.ox.ac.uk'...
# [INFO] Cleanup complete.
```
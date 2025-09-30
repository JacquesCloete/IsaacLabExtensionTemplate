# Cluster Deployment (Requires Container Installation)

The method we use for cluster deployment was adapted from the [Isaac Lab Cluster
Guide](https://isaac-sim.github.io/IsaacLab/main/source/deployment/cluster.html),
modified to work for the extension. It's recommended to first read through that guide
before proceeding.

For guidance on using the Oxford ARC/HTC cluster, refer to [this
guide](https://arc-user-guide.readthedocs.io/en/latest/).

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

Edit `docker/cluster/.env.cluster` to suit your needs.

## 3 Exporting to a Singularity Image

Run the following on your local machine:
```bash
./docker/cluster/cluster_interface.sh push
```
This may take a while, so give it some time.

## 4 Define the Job Parameters

Edit `docker/cluster/submit_job_slurm.sh` to suit your needs.

## 5 Submit a Job

You can submit a job to the cluster directly from your local machine as follows (make
sure the `--headless` flag is enabled!):
```bash
./docker/cluster/cluster_interface.sh job --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
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
```

To follow job logs from your local machine (for job ID `12345`):
```bash
./docker/cluster/cluster_interface.sh logs 12345
```

To cancel a job from your local machine (for job ID `12345`):
```bash
./docker/cluster/cluster_interface.sh cancel 12345
```

## 7 Copying Logs to Local Machine

To copy logs from the cluster back to the local machine, run the following:
```bash
./docker/cluster/cluster_interface.sh copy
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
```
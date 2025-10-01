# Remote Workstation Deployment (Requires Container Installation)

The method we use for remote workstation deployment was inspired by the approach for
cluster deployment (see [here](/docker/cluster/README.md)).

## A Word of Caution

During operation, the container creates root-owned files bind-mounted onto the remote
workstation. While these files are made user-owned at the end of normal operation, under
exceptional circumstances (docker daemon crash, kernel panic, etc.) mid-execution, these
files could remain root-owned and thus unable to be deleted by users without `sudo`
permissions.

Make sure you can contact someone with `sudo` permissions on the remote workstation, in
case you need the files deleted using `sudo`. If this is not possible, it's probably
safest to manually install and run the container "locally" on the remote workstation
instead (as if it were your local machine).

## 1 Remote Workstation Parameters

Edit [`docker/remote/.env.remote`](/docker/remote/.env.remote) to suit your needs.

## 2 Exporting to the Remote Workstation

Run the following on your local machine:
```bash
./docker/remote/remote_interface.sh push
# Executing push command
# Using suffix: my_extension
# [INFO] Pushing docker image 'isaac-lab-ext-my_extension:latest' to 'jacques@sirius'...
# Loaded image: isaac-lab-ext-my_extension:latest
# [INFO] Push complete.
```
This may take a while, so give it some time.

## 3 Submitting a Job

You can submit a job to the remote workstation directly from your local machine as
follows (make sure the `--headless` flag is enabled!):
```bash
./docker/remote/remote_interface.sh job --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# [INFO] Executing job command
# 	Using suffix: my_extension
# 	Job arguments: --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# [INFO] Syncing Isaac Lab code...
# [INFO] Syncing Isaac Lab Extension code...
# [INFO] Executing job script...
# [INFO] Arguments passed to job script --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# (run_docker.sh): Called on remote machine from project directory /home/jacques/remote/isaac-lab-ext-my_extension_20251001_141540 with image name isaac-lab-ext-my_extension and arguments --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# 00294b001050e1f8c72f56443a8e4b164b9521623e7044c3c7db8e1266ca1cac
# (run_docker.sh): Return
# Submitted job with ID: train-20251001_141540
```
This will copy over the present contents of Isaac Lab and your extension onto the remote
workstation in a timestamped "temporary" folder and then start the training job.

All training logs will be neatly saved in a separate "permanent" folder on the remote
workstation, which you can access during and after training.

## 4 Job Monitoring

To check job status from your local machine:
```bash
./docker/remote/remote_interface.sh status
# [INFO] Checking status on remote workstation...
# CONTAINER ID   IMAGE                        COMMAND                   CREATED          STATUS          PORTS     NAMES
# 00294b001050   isaac-lab-ext-my_extension   "bash -c '\ntrap 'cho…"   55 seconds ago   Up 54 seconds             train-20251001_141540
```

To follow job logs from your local machine:
```bash
./docker/remote/remote_interface.sh logs train-20251001_141540
# [INFO] Tailing logs for job 'train-20251001_141540'...
# ...
```

To cancel a job from your local machine:
```bash
./docker/remote/remote_interface.sh cancel train-20251001_141540
# [INFO] Cancelling job 'train-20251001_141540'...
# train-20251001_141540
```

Note the project suffix (rather than job ID) is used to identify jobs on the remote workstation.

## 5 Copying Logs to Local Machine

To copy logs from the remote workstation back to the local machine, run the following:
```bash
./docker/remote/remote_interface.sh copy
# [INFO] Copying logs from the remote machine...
# [INFO] Syncing logs from 'jacques@sirius:/home/jacques/remote/isaac-lab-ext-my_extension/logs/' to '/home/jacques/projects/IsaacLabMyExtension/docker/remote/../../logs/'...
# ...
# [INFO] Log synchronization complete.
```

If you get an `Operation not permitted`/`Permission Denied` error, then first run the following
on your local machine:
```bash
sudo chown -R $USER:$USER logs/ docs/ data_storage/
```

## 6 Cleaning Up Code

To clean up space on the remote workstation, you can delete all timestamped "temporary"
folders by running the following on your local machine:
```bash
./docker/remote/remote_interface.sh cleanup
# [INFO] Executing cleanup command
# [INFO] Deleting directories matching 'isaac-lab-ext-my_extension_*' in '/home/jacques/remote' on 'jacques@sirius'...
# [INFO] Cleanup complete.
```
# Extension Template for Isaac Lab Projects

[![IsaacSim](https://img.shields.io/badge/IsaacSim-5.0.0-silver.svg)](https://docs.omniverse.nvidia.com/isaacsim/latest/overview.html)
[![Isaac
Lab](https://img.shields.io/badge/IsaacLab-2.2.1-silver)](https://isaac-sim.github.io/IsaacLab)
[![Python](https://img.shields.io/badge/python-3.11-blue.svg)](https://docs.python.org/3/whatsnew/3.11.html)
[![Linux
platform](https://img.shields.io/badge/platform-linux--64-orange.svg)](https://releases.ubuntu.com/22.04/)
[![Windows
platform](https://img.shields.io/badge/platform-windows--64-orange.svg)](https://www.microsoft.com/en-us/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://pre-commit.com/)
[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/license/mit)

# Overview

This repository serves as a template for building extension projects for Isaac Lab. It
allows you to develop in an isolated environment, outside of the core Isaac Lab
repository.

**Key Features:**

- `Isolation` Work outside the core Isaac Lab repository, ensuring that your development
  efforts remain self-contained.
- `Flexibility` This template is set up to allow your code to be run in a container, and
  deployed remotely on a cluster.

**Keywords:** extension, template, isaaclab

# Container Installation (Recommended, Especially for Remote Training)

## 1 Building Isaac Lab Base Image

Start by following [Isaac Lab Docker
guide](https://isaac-sim.github.io/IsaacLab/main/source/deployment/docker.html) to build
the base Isaac Lab image locally.

**NOTE:** If you are using a workstation shared by multiple users, you **must** add a
unique suffix to your version of the base image to prevent overriding other peoples'
Isaac Lab images.

You add a suffix (e.g. `jacques`) as follows:
```bash
/path/to/IsaacLab/docker/container.py start --suffix jacques
```
You must always add the suffix as an argument when interacting with the base container
using `container.py`.

Once you have built your base Isaac Lab image, you can check it exists by doing:

```bash
docker images
# REPOSITORY                       TAG       IMAGE ID       CREATED          SIZE
# isaac-lab-base-jacques           latest    28be62af627e   32 minutes ago   17.7GB
# ...
```

## 2 Building the Extension Image

First, create a new GitHub repository from the template repository. We will create the
repository `IsaacLabMyExtension` under user `Jacques` for this guide.

Then, clone the repository separately from the Isaac Lab installation (i.e. outside the
`IsaacLab` directory):

```bash
# Option 1: SSH (recommended)
git clone git@github.com:Jacques/IsaacLabMyExtension.git

# Option 2: HTTPS
git clone https://github.com/Jacques/IsaacLabMyExtension.git
```

Then rename the contents of the repository to a new project name. We will use
`my_extension` for this guide. This can be done automatically as follows:
```bash
# Enter the repository
cd IsaacLabMyExtension
# Rename all occurrences of ext_template (in files/directories) to my_extension
python scripts/rename_template.py my_extension
```
**NOTE:** To avoid Python syntax errors, the project name must be defined in
[`snake_case`](https://en.wikipedia.org/wiki/Snake_case); all lower case with words
separated by underscores, and no hyphens.

Then, in a similar approach to building the base image, build the docker container for
your extension project:

1. Edit [`docker/.env.ext`](/docker/.env.ext) to specify your base image name
1. Build the container using:
```bash
docker/container.py start
# [INFO] Using container suffix: -my_extension
# [INFO] X11 Forwarding is configured as '1' in '.container.cfg'.
# 	To disable X11 forwarding, set 'X11_FORWARDING_ENABLED=0' in '.container.cfg'.
# [INFO] Building the docker image and starting the container 'isaac-lab-ext-my_extension' in the background...
# ...
```
Note that `--suffix` is not needed when interacting with your extension image using
`container.py` in the extension project.

If prompted about enabling X11 forwarding, choose `y` if you want to use GUIs from
within the container, else `n`.

You can verify your extension image (which will always have the profile `ext`) is built
successfully using the same command as earlier:

```bash
docker images
# REPOSITORY                       TAG       IMAGE ID       CREATED             SIZE
# isaac-lab-ext-my_extension       latest    00b00b647e1b   2 minutes ago       17.7GB
# isaac-lab-base-jacques           latest    28be62af627e   About an hour ago   17.7GB
# ...
```

## 3 Using the Extension Container

### 3.1 Running the container

If the image exists, you can start the container as follows:

```bash
docker/container.py start
# [INFO] Using container suffix: -my_extension
# [INFO] X11 Forwarding is configured as '1' in '.container.cfg'.
# 	To disable X11 forwarding, set 'X11_FORWARDING_ENABLED=0' in '.container.cfg'.
# [INFO] Building the docker image and starting the container 'isaac-lab-ext-my_extension' in the background...
# ...
```

### 3.2 Interacting with a running container

To enter the container once started, use:

```bash
docker/container.py enter
# [INFO] Using container suffix: -my_extension
# [INFO] X11 Forwarding is enabled from the settings in '.container.cfg'
# [INFO] Entering the existing 'isaac-lab-ext-my_extension' container in a bash session...
```

Alternatively, if you use VSCode, I instead recommend pressing `Ctrl+Shift+P`, selecting
`Dev Containers: Attach to Running Container...` and then selecting your container. This
will re-open VSCode inside the container (including integrated terminals).

To verify the container is correctly built, run the following command inside the
container:
```bash
./isaaclab_ext.sh -p scripts/rsl_rl/train.py --task Ext-Isaac-Velocity-Rough-Anymal-D-v0
# [INFO] Using python from: /workspace/isaaclab_ext/../isaaclab/_isaac_sim/python.sh      
# ...
```

**NOTE:** When running Isaac Sim with GUI (i.e. without the `--headless` flag) for the
first time, it will take a while to finish loading. Be patient. You will likely see
repeated pop-ups that say `"Isaac Sim" is not Responding` in the GUI, just keep pressing
`Wait` until loading completes.

You can use `Ctrl+C` in terminal to kill the run, then `exit` to exit the container.

### 3.2.1 Interacting with the container from the local machine

Once the container is started, you can instead interact with it "remotely" from the local machine,
without entering the container.

To submit a job:
```bash
docker/container.py job scripts/rsl_rl/train.py --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
# [INFO] Using container suffix: -my_extension
# [INFO] Submitting job 'train-20251001_135743' to container 'isaac-lab-ext-my_extension'...
# [INFO] Successfully submitted job. Use 'status' to check and 'cancel train-20251001_135743' to stop.
```

To check job status:
```bash
docker/container.py status
# [INFO] Using container suffix: -my_extension
# [INFO] Checking job status in container 'isaac-lab-ext-my_extension'...
# Running jobs:
#   - train-20251001_135743
```

To follow job logs:
```bash
docker/container.py logs train-20251001_135743
# [INFO] Using container suffix: -my_extension
# [INFO] Following logs for job 'train-20251001_135743' in container 'isaac-lab-ext-my_extension'...
# [INFO] Press Ctrl+C to stop following.
# ...
```

To cancel a job:
```bash
docker/container.py cancel train-20251001_135743
# [INFO] Using container suffix: -my_extension
# [INFO] Attempting to cancel job 'train-20251001_135743' in container 'isaac-lab-ext-my_extension'...
# Successfully cancelled job train-20251001_135743.
```

### 3.3 Shutting down the container

When you are done or want to stop the running container, you can run the following:

```bash
docker/container.py stop
# [INFO] Using container suffix: -my_extension
# [INFO] Stopping the launched docker container 'isaac-lab-ext-my_extension'...
# ...
```

This stops and removes the container, but keeps the image.

# Local Installation

## 1 Installing Isaac Lab

Install Isaac Lab locally by following the
[installation guide](https://isaac-sim.github.io/IsaacLab/main/source/setup/installation/pip_installation.html).
We recommend installing in a dedicated conda environment for your project.

## 2 Installing the Extension

First, create a new GitHub repository from the template repository. We will create the
repository `IsaacLabMyExtension` under user `Jacques` for this guide.

Then, clone the repository separately from the Isaac Lab installation (i.e. outside the
`IsaacLab` directory):

```bash
# Option 1: SSH (recommended)
git clone git@github.com:Jacques/IsaacLabMyExtension.git

# Option 2: HTTPS
git clone https://github.com/Jacques/IsaacLabMyExtension.git
```

Then rename the contents of the repository from to a new project name. We will use
`my_extension` for this guide. This can be done automatically as follows:
```bash
# Enter the repository
cd IsaacLabMyExtension
# Rename all occurrences of ext_template (in files/directories) to my_extension
python scripts/rename_template.py my_extension
```

Using the python interpreter that has Isaac Lab installed (e.g., with your dedicated
project conda environment activated), install the extension project:

```bash
python -m pip install -e source/ext_template
```

## 3 Using the Extension

Verify that the extension is correctly installed by running the following command:

```bash
python scripts/rsl_rl/train.py --task Ext-Isaac-Velocity-Rough-Anymal-D-v0
```

# Remote Workstation Deployment (Requires Container Installation)

For guidance on how to use the container on a remote workstation, see [this page](/docker/remote/README.md).

# Cluster Deployment (Requires Container Installation)

For guidance on how to use the container on a cluster, see [this page](/docker/cluster/README.md).

# Tips and Suggestions

It is strongly recommended to read all of the below before using this repository.

## Setting up VSCode IDE

To setup the IDE, run VSCode Tasks by pressing `Ctrl+Shift+P`, then selecting `Tasks:
Run Task` and then running the `setup_python_env` in the drop down menu. When running
this task, you will be prompted to check the absolute path for your Isaac Sim
installation. By default, this should be set up to work for the docker container.

If everything executes correctly, it should create files in the `.vscode` directory.
These files contain the python paths to all the extensions provided by Isaac Sim and
Omniverse. This helps in indexing all the python modules for intelligent suggestions
while writing code.

If using the container, you will have to re-run this every time you start the container.

**NOTE:** VSCode IDE is **not** supported for local pip-based installations (e.g., if
you're using a conda environment).

## Weights and Biases Support for Containers

The containers are set up to support Weights and Biases (including on clusters), and can
link training runs automatically to your account.

For this to work, you must have your Weights and Biases API key exported as an
environment variable. The easiest way to do this is to append your user account's
`~/.bashrc` file with the following:
```bash
export WANDB_API_KEY=[your API key here]
```
Then source the `~/.bashrc` file, or simply open a new terminal. The `~/.bashrc` file to
append to depends on where the container is running:

| Location           | `~/.bashrc` file                           |
|--------------------|--------------------------------------------|
| Local machine      | Local machine user login                   |
| Remote workstation | Local machine user login (**not** remote!) |
| Cluster            | Cluster user login                         |

**NOTE:** interactively SSHing in to the remote workstation and manually running the
container from there counts as "local machine" but applied to the remote workstation, so
you'd need to edit the `~/.bashrc` on the remote workstation in that case.

To train using RSL-RL with Weights and Biases enabled inside the container on your local
machine, run the following:
```
./isaaclab_ext.sh -p scripts/rsl_rl/train.py --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless --logger wandb --log_project_name isaac-lab-ext-ext_template --run_name docker_test
```

## Automatic Login on Remote Servers

To avoid needing to type in your password several times when deploying your container
remotely, we recommend copying your public SSH key to the remote machine.

First check that you already have a key on your local machine:
```bash
ls ~/.ssh/id_rsa.pub
```

If you do not yet have a key, you can generate a new one:
```bash
ssh-keygen -t rsa
```

Then, to copy your key onto the remote machine:
```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub username@remote.example.com
```

**NOTE:** Only do this for private user accounts on remote machines, do not do this for
a shared account!

## Volume vs Bind Mounts

There are two ways to mount the `logs`/`docs`/`data_storage` folders to the local
machine:
1. **Volume** *(default)*:
    - The folders in the container get mounted to Docker volumes on the local machine,
      safely stored in `/var/lib/docker/volumes/`.
    - The contents can then be copied from these volumes into the user's workspace, but
      changes on the local machine will not appear in the container.
    - The contents of the volumes will be lost when the container is stopped.
    - **Prevents root-owned files leaking into the user's workspace.**
1. **Bind**:
    - The folders in the container get directly mounted to those on the local machine.
    - Any changes from one end will immediately show up on the other.
    - The contents of the folders will persist after the container is stopped.
    - **All files created by the container will be root-owned, and require `sudo`
      permissions to modify/delete from outside the container.**

You can choose which you want to use by commenting/uncommenting the relevant blocks in
[docker/docker-compose.yaml](/docker/docker-compose.yaml):
- If your user account has `sudo` permissions, then it's fine (and indeed very
  convenient) to use bind mounts.
- If not, it's safest to use volume mounts.

For remote workstation and cluster deployment, they are always bind-mounted (but this is
handled for you under the hood).

# Troubleshooting

Here we troubleshoot some common issues when using this repository.

## Permissions Issues for `logs`/`docs`/`data_storage`

If bind mounts are used for `logs`/`docs`/`data_storage` on the container, then you can run into
permissions issues when interacting with these directories on the local machine. To fix,
you can run the following:
```bash
sudo chown -R $USER:$USER logs/ docs/ data_storage/
```
Note that this requires `sudo` permissions.

## Runaway Processes in Container

If you submit a job to the container from your local machine and, for some reason, the
process still continues to run inside the container even after you've canceled the job,
then you can manually enter the container and brute-force kill the process.

Suppose that our script `train.py` is still running on the container:
```bash
root@ori-31397:/workspace/isaaclab_ext pgrep -af train.py  # list running processes with train.py
# 692 /bin/bash /isaac-sim/python.sh scripts/rsl_rl/train.py --task Ext-Isaac-Velocity-Rough-Anymal-D-v0 --headless
root@ori-31397:/workspace/isaaclab_ext pkill -f train.py # brute-force kill processes with train.py
```

## Pylance Missing Indexing of Extensions

In some VsCode versions, the indexing of part of the extensions is missing. In this
case, add the path to your extension in `.vscode/settings.json` under the key
`"python.analysis.extraPaths"`.

```json
{
    "python.analysis.extraPaths": [
        "<path-to-ext-repo>/source/ext_template"
    ]
}
```

## Pylance Crash

If you encounter a crash in `pylance`, it is probable that too many files are indexed
and you run out of memory. A possible solution is to exclude some of omniverse packages
that are not used in your project. To do so, modify `.vscode/settings.json` and comment
out packages under the key `"python.analysis.extraPaths"` Some examples of packages that
can likely be excluded are:

```json
"<path-to-isaac-sim>/extscache/omni.anim.*"         // Animation packages
"<path-to-isaac-sim>/extscache/omni.kit.*"          // Kit UI tools
"<path-to-isaac-sim>/extscache/omni.graph.*"        // Graph UI tools
"<path-to-isaac-sim>/extscache/omni.services.*"     // Services tools
...
```
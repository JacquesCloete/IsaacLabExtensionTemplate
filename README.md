# Extension Template for Isaac Lab Projects

[![IsaacSim](https://img.shields.io/badge/IsaacSim-5.0.0-silver.svg)](https://docs.omniverse.nvidia.com/isaacsim/latest/overview.html)
[![Isaac Lab](https://img.shields.io/badge/IsaacLab-2.2.1-silver)](https://isaac-sim.github.io/IsaacLab)
[![Python](https://img.shields.io/badge/python-3.11-blue.svg)](https://docs.python.org/3/whatsnew/3.11.html)
[![Linux platform](https://img.shields.io/badge/platform-linux--64-orange.svg)](https://releases.ubuntu.com/22.04/)
[![Windows platform](https://img.shields.io/badge/platform-windows--64-orange.svg)](https://www.microsoft.com/en-us/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://pre-commit.com/)
[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/license/mit)

## Overview

This repository serves as a template for building extension projects for Isaac Lab. It allows you to develop in an isolated environment, outside of the core Isaac Lab repository.

**Key Features:**

- `Isolation` Work outside the core Isaac Lab repository, ensuring that your development efforts remain self-contained.
- `Flexibility` This template is set up to allow your code to be run in a container, and
  deployed remotely on a cluster.

**Keywords:** extension, template, isaaclab

## Container Installation (Recommended, Especially for Remote Training)

### 1 Building Isaac Lab Base Image

Start by following [Isaac Lab Docker
guide](https://isaac-sim.github.io/IsaacLab/main/source/deployment/docker.html) to build
the base Isaac Lab image locally.

**NOTE:** If you are using a workstation shared by multiple users, you **must** add a
unique suffix to your version of
the base image to prevent overriding other peoples' Isaac Lab images.

You add a suffix (e.g. `jacques`) as follows:
```bash
/path/to/IsaacLab/docker/container.py start --suffix jacques
```
You must always add the suffix as an argument when interacting with the base container using `container.py`.

Once you have built your base Isaac Lab image, you can check it exists by doing:

```bash
docker images

# Output should look something like:
#
# REPOSITORY                       TAG       IMAGE ID       CREATED          SIZE
# isaac-lab-base-jacques           latest    28be62af627e   32 minutes ago   17.7GB
```

### 2 Building the Extension Image

First, create a new GitHub repository from the template repository. We will create the
repository `IsaacLabMyExtension` under user `Jacques` for this guide.

Then, clone the repository separately from the Isaac Lab installation (i.e. outside the `IsaacLab` directory):

```bash
# Option 1: SSH (recommended)
git clone git@github.com:Jacques/IsaacLabMyExtension.git

# Option 2: HTTPS
git clone https://github.com/Jacques/IsaacLabMyExtension.git
```

Then rename the contents of the repository to a new project name. We
will use `my-extension` for this guide. This can be done automatically as follows:
```bash
# Enter the repository
cd IsaacLabMyExtension
# Rename all occurrences of ext_template (in files/directories) to my-extension
python scripts/rename_template.py my-extension
```

Then, in a similar approach to building the base image, build the docker container for your extension project:

1. Edit `/path/to/IsaacLabMyExtension/docker/.env.ext` to specify your base image name
1. Build the container using:
```bash
/path/to/IsaacLabMyExtension/docker/.container.py start
```
Note that `--suffix` is not needed when interacting with your extension image using
`container.py` in the extension project.

You can verify your extension image (which will always have the profile `ext`) is built successfully using the same command as earlier:

```bash
docker images

# Output should look something like:
#
# REPOSITORY                       TAG       IMAGE ID       CREATED             SIZE
# isaac-lab-ext-my-extension       latest    00b00b647e1b   2 minutes ago       17.8GB
# isaac-lab-base-jacques           latest    28be62af627e   About an hour ago   17.7GB
```

### 3 Using the Extension Container

#### 3.1 Running the container

if the image exists, you can start the container as follows:

```bash
/path/to/IsaacLabMyExtension/docker/.container.py start
```

#### 3.2 Interacting with a running container

To enter the container once started, use:

```bash
/path/to/IsaacLabMyExtension/docker/.container.py enter
```

Alternatively, if you use VSCode, I instead recommend pressing `Ctrl+Shift+P`, selecting
`Dev Containers: Attach to Running Container...` and then selecting your container. This
will re-open VSCode inside the container (including integrated terminals).

To verify the container is correctly built, run the following command inside the container:
```bash
./isaaclab_ext.sh -p scripts/rsl_rl/train.py --task Ext-Isaac-Velocity-Rough-Anymal-D-v0
```

#### 3.3 Shutting down the container

When you are done or want to stop the running container, you can run the following:

```bash
/path/to/IsaacLabMyExtension/docker/.container.py stop
```

This stops and removes the container, but keeps the image.

## Local Installation

### 1 Installing Isaac Lab

- Install Isaac Lab locally by following the [installation
  guide](https://isaac-sim.github.io/IsaacLab/main/source/setup/installation/pip_installation.html).
  We recommend installing in a dedicated conda environment for your project.

### 2 Installing the Extension

First, create a new GitHub repository from the template repository. We will create the
repository `IsaacLabMyExtension` under user `Jacques` for this guide.

Then, clone the repository separately from the Isaac Lab installation (i.e. outside the `IsaacLab` directory):

```bash
# Option 1: SSH (recommended)
git clone git@github.com:Jacques/IsaacLabMyExtension.git

# Option 2: HTTPS
git clone https://github.com/Jacques/IsaacLabMyExtension.git
```

Then rename the contents of the repository from to a new project name. We
will use `my-extension` for this guide. This can be done automatically as follows:
```bash
# Enter the repository
cd IsaacLabMyExtension
# Rename all occurrences of ext_template (in files/directories) to my-extension
python scripts/rename_template.py my-extension
```

Using the python interpreter that has Isaac Lab installed (e.g., with your dedicated
project conda environment activated), install the extension project:

```bash
python -m pip install -e source/ext_template
```

### 3 Using the Extension

Verify that the extension is correctly installed by running the following command:

```bash
python scripts/rsl_rl/train.py --task Ext-Isaac-Velocity-Rough-Anymal-D-v0
```

## Cluster Deployment (Requires Container Installation)

The method we use for cluster deployment was adapted from the [Isaac Lab Cluster
Guide](https://isaac-sim.github.io/IsaacLab/main/source/deployment/cluster.html),
modified to work for the extension. It's recommended to first read through that guide
before proceeding.

For guidance on using the Oxford ARC/HTC cluster, refer to [this guide](https://arc-user-guide.readthedocs.io/en/latest/).

### 1 Installing Apptainer

Run the following on your local machine:

```bash
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt update
sudo apt install -y apptainer
```

### 2 Exporting to a Singularity Image

Run the following on your local machine:
```bash
./docker/cluster/cluster_interface.sh push
```
This may take a while, so give it some time.

### 3 Define the Cluster Parameters

Edit `docker/cluster/submit_job_slurm.sh` to suit your needs.

### 4 Submit a Job

You can submit a job to the cluster directly from your local machine as follows (make
sure the `--headless` flag is enabled!):
```bash
./docker/cluster/cluster_interface.sh job --task Template-Isaac-Velocity-Rough-Anymal-D-v0 --headless
```
This will copy over the present contents of Isaac Lab and your extension onto the cluster in a
timestamped "temporary" folder and then start the training job.

All training logs will be neatly saved in a separate "permanent" folder in the cluster,
which you can access during and after training (e.g., for copying back onto your local machine).

### Cleaning Up Code

To clean up space on the cluster, you can delete all timestamped "temporary" folders by
running the following on your local machine:
```bash
./docker/cluster/cluster_interface.sh cleanup
```

## Tips and Troubleshooting

### Setting up VSCode IDE

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

### Automatic Login on Remote Servers

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

### Weights and Biases Support for Containers

The containers are set up to support Weights and Biases (including on clusters), and
can link training runs automatically to your account.

For this to work, you must have your Weights and Biases API key exported as an
environment variable on whichever machine is running the container. The easiest way to
do this is to append your user account's `~/.bashrc` file with the following:
```bash
export WANDB_API_KEY=[your API key here]
```
Then source the `~/.bashrc` file, or simply open a new terminal. Note this will need to be
done on your cluster user account if training on a cluster.

To train using RSL-RL with Weights and Biases enabled inside the container, run the following:
```
./isaaclab_ext.sh -p scripts/rsl_rl/train.py --task Template-Isaac-Velocity-Rough-Anymal-D-v0 --headless --logger wandb --log_project_name isaac-lab-ext-ext_template --run_name docker_test
```

### Pylance Missing Indexing of Extensions

In some VsCode versions, the indexing of part of the extensions is missing. In this case, add the path to your extension in `.vscode/settings.json` under the key `"python.analysis.extraPaths"`.

```json
{
    "python.analysis.extraPaths": [
        "<path-to-ext-repo>/source/ext_template"
    ]
}
```

### Pylance Crash

If you encounter a crash in `pylance`, it is probable that too many files are indexed and you run out of memory.
A possible solution is to exclude some of omniverse packages that are not used in your project.
To do so, modify `.vscode/settings.json` and comment out packages under the key `"python.analysis.extraPaths"`
Some examples of packages that can likely be excluded are:

```json
"<path-to-isaac-sim>/extscache/omni.anim.*"         // Animation packages
"<path-to-isaac-sim>/extscache/omni.kit.*"          // Kit UI tools
"<path-to-isaac-sim>/extscache/omni.graph.*"        // Graph UI tools
"<path-to-isaac-sim>/extscache/omni.services.*"     // Services tools
...
```
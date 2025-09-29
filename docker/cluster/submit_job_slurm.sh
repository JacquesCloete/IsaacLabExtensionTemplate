#!/usr/bin/env bash

# in the case you need to load specific modules on the cluster, add them here
# e.g., `module load eth_proxy`

# create job script with compute demands
### MODIFY HERE FOR YOUR JOB ###
cat <<EOT > job.sh
#!/bin/bash

# The arguments are:
# $1: Path to the (timestamped) project directory on the cluster
# $2: The container name (e.g., isaac-lab-ext-ext_template)
# "${@:3}": Any additional arguments for the task

#SBATCH --job-name="$2-$(date +"%Y-%m-%dT%H:%M")"
#SBATCH --output="$2-%j.out"
#SBATCH --error="$2-%j.err"
#SBATCH --partition=short
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --gres=gpu:rtx8000:1
#SBATCH --constraint=os:redhat8
#SBATCH --export=WANDB_API_KEY

# Load any necessary modules
# module load ...

# Execute the singularity container
# Pass the container profile first to run_singularity.sh, then all arguments intended for the executed script
bash "$1/isaaclab_ext/docker/cluster/run_singularity.sh" "$1" "$2" "${@:3}"
EOT

# Submit the job to SLURM
sbatch < job.sh

# Clean up the temporary script
rm job.sh

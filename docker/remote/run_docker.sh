#!/usr/bin/env bash

# The arguments are:
# $1: Path to the (timestamped) project directory on the remote machine
# $2: The container name (e.g., isaac-lab-ext-ext_template)
# $3: The job name for the container
# "${@:4}": Any additional arguments for the task

# TIMESTAMPED_PROJECT_DIR="$1"
# IMAGE_NAME="$2"
# JOB_NAME="$3"
# shift 3
# TASK_ARGS="${@:4}"

echo "(run_docker.sh): Called on remote machine from project directory $1 with image name $2 and arguments ${@:4}"

#==
# Helper functions
#==

setup_directories() {
    # Check and create directories
    for dir in \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/kit" \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/ov" \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/pip" \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/glcache" \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/computecache" \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/logs" \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/data" \
        "${REMOTE_ISAAC_SIM_CACHE_DIR}/documents"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "Created directory: $dir"
        fi
    done
}

#==
# Main
#==

# get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# load variables to set the Isaac Lab Extension path on the remote machine
source $SCRIPT_DIR/.env.remote
source $SCRIPT_DIR/../.env.ext

# make sure that all directories exists in cache directory
setup_directories

# Make sure logs directory exists
mkdir -p "$REMOTE_PROJECT_DIR/logs"

# Check if a container with the same name is already running
if [ "$(docker ps -q -f name=$3)" ]; then
    echo "Error: A job with the name '$3' is already running."
    exit 1
fi

# Get the host user's UID and GID to pass to the container
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# This is the command that will be executed inside the container.
# It runs the training script and then, critically, runs `chown` to fix file permissions
# on the mounted directories before the container exits.
# The `trap` ensures the chown command runs even if the job is cancelled (e.g., with `docker stop`).
INNER_COMMAND="
trap 'chown -R ${HOST_UID}:${HOST_GID} \
    /workspace/isaaclab_ext/logs \
    ${DOCKER_ISAACSIM_ROOT_PATH}/kit/cache \
    ${DOCKER_USER_HOME}/.cache/ov \
    ${DOCKER_USER_HOME}/.cache/pip \
    ${DOCKER_USER_HOME}/.cache/nvidia/GLCache \
    ${DOCKER_USER_HOME}/.nv/ComputeCache \
    ${DOCKER_USER_HOME}/.nvidia-omniverse/logs \
    ${DOCKER_USER_HOME}/.local/share/ov/data \
    ${DOCKER_USER_HOME}/Documents' EXIT

export ISAACLAB_PATH=/workspace/isaaclab && export ISAACLAB_EXT_PATH=/workspace/isaaclab_ext && cd /workspace/isaaclab_ext && /isaac-sim/python.sh ${REMOTE_PYTHON_EXECUTABLE} ${@:4}
"


# Execute command in docker container.
# We run as root, but the INNER_COMMAND will fix permissions on exit.
docker run --rm -d -it --network=host --gpus device=${REMOTE_GPU_ID} --name "$3" \
    --label "managed-by=remote-interface" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/kit:${DOCKER_ISAACSIM_ROOT_PATH}/kit/cache:rw" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/ov:${DOCKER_USER_HOME}/.cache/ov:rw" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/pip:${DOCKER_USER_HOME}/.cache/pip:rw" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/glcache:${DOCKER_USER_HOME}/.cache/nvidia/GLCache:rw" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/cache/computecache:${DOCKER_USER_HOME}/.nv/ComputeCache:rw" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/logs:${DOCKER_USER_HOME}/.nvidia-omniverse/logs:rw" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/data:${DOCKER_USER_HOME}/.local/share/ov/data:rw" \
    -v "${REMOTE_ISAAC_SIM_CACHE_DIR}/documents:${DOCKER_USER_HOME}/Documents:rw" \
    -v "$1/isaaclab:/workspace/isaaclab:rw" \
    -v "$1/isaaclab_ext:/workspace/isaaclab_ext:rw" \
    -v "$REMOTE_PROJECT_DIR/logs:/workspace/isaaclab_ext/logs:rw" \
    -e "WANDB_API_KEY=${WANDB_API_KEY}" \
    -e "OMNI_KIT_ALLOW_ROOT=1" \
    --entrypoint bash \
    "$2" \
    -c "${INNER_COMMAND}"

echo "(run_docker.sh): Return"
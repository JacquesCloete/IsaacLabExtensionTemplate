#!/usr/bin/env bash

echo "(run_singularity.py): Called on compute node from project directory $1 with container name $2 and arguments ${@:3}"

#==
# Helper functions
#==

setup_directories() {
    # Check and create directories
    for dir in \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/cache/kit" \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/cache/ov" \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/cache/pip" \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/cache/glcache" \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/cache/computecache" \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/logs" \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/data" \
        "${CLUSTER_ISAAC_SIM_CACHE_DIR}/documents"; do
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

# load variables to set the Isaac Lab Extension path on the cluster
source $SCRIPT_DIR/.env.cluster
source $SCRIPT_DIR/../.env.ext

# make sure that all directories exists in cache directory
setup_directories
# copy all cache files
cp -r $CLUSTER_ISAAC_SIM_CACHE_DIR $TMPDIR

# make sure logs directory exists (in the permanent project directory)
mkdir -p "$CLUSTER_PROJECT_DIR/logs"
touch "$CLUSTER_PROJECT_DIR/logs/.keep"

# copy the temporary project directory with the latest changes to the compute node
cp -r $1 $TMPDIR
# Get the directory name
dir_name=$(basename "$1")

# copy container to the compute node
tar -xf $CLUSTER_SIF_PATH/$2.tar  -C $TMPDIR

# execute command in singularity container
# NOTE: ISAACLAB_PATH is normally set in `isaaclab_ext.sh` but we directly call the isaac-sim python because we sync the entire
# Isaac Lab directory to the compute node and remote the symbolic link to isaac-sim
SINGULARITYENV_WANDB_API_KEY=$WANDB_API_KEY singularity exec \
    -B $TMPDIR/docker-isaac-sim/cache/kit:${DOCKER_ISAACSIM_ROOT_PATH}/kit/cache:rw \
    -B $TMPDIR/docker-isaac-sim/cache/ov:${DOCKER_USER_HOME}/.cache/ov:rw \
    -B $TMPDIR/docker-isaac-sim/cache/pip:${DOCKER_USER_HOME}/.cache/pip:rw \
    -B $TMPDIR/docker-isaac-sim/cache/glcache:${DOCKER_USER_HOME}/.cache/nvidia/GLCache:rw \
    -B $TMPDIR/docker-isaac-sim/cache/computecache:${DOCKER_USER_HOME}/.nv/ComputeCache:rw \
    -B $TMPDIR/docker-isaac-sim/logs:${DOCKER_USER_HOME}/.nvidia-omniverse/logs:rw \
    -B $TMPDIR/docker-isaac-sim/data:${DOCKER_USER_HOME}/.local/share/ov/data:rw \
    -B $TMPDIR/docker-isaac-sim/documents:${DOCKER_USER_HOME}/Documents:rw \
    -B $TMPDIR/$dir_name/isaaclab:/workspace/isaaclab:rw \
    -B $TMPDIR/$dir_name/isaaclab_ext:/workspace/isaaclab_ext:rw \
    -B $CLUSTER_PROJECT_DIR/logs:/workspace/isaaclab_ext/logs:rw \
    --nv --writable --containall $TMPDIR/$2.sif \
    bash -c "export ISAACLAB_PATH=/workspace/isaaclab && export ISAACLAB_EXT_PATH=/workspace/isaaclab_ext && cd /workspace/isaaclab_ext && /isaac-sim/python.sh ${CLUSTER_PYTHON_EXECUTABLE} ${@:3}"

# copy resulting cache files back to host
rsync -azPv $TMPDIR/docker-isaac-sim $CLUSTER_ISAAC_SIM_CACHE_DIR/..

echo "(run_singularity.py): Return"

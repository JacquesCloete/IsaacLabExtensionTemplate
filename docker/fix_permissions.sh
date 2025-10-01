#!/usr/bin/env bash

# This script runs a temporary Docker container to fix file permissions on the
# /workspace/isaaclab_ext directory.
#
# The script takes one optional argument:
# $1: The container name suffix. Defaults to 'ext_template'.

# Exits if error occurs
set -e

#==
# Main
#==

# Get script directory to determine the project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_DIR="$SCRIPT_DIR/.."

# Determine suffix and image name
suffix=${1:-"ext_template"}
IMAGE_NAME="isaac-lab-ext-$suffix"

echo "[INFO] Using image: $IMAGE_NAME"

# Check if the docker image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "[Error] The '$IMAGE_NAME' image does not exist!" >&2;
    echo "[Error] You might be able to build it with ./docker/container.py --suffix $suffix" >&2;
    exit 1
fi

# Get the host user's UID and GID to pass to the container
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# This is the command that will be executed inside the container.
# It runs `chown` to fix file permissions on the mounted directory.
INNER_COMMAND="chown -R ${HOST_UID}:${HOST_GID} /workspace/isaaclab_ext"

echo "[INFO] Fixing permissions for directory: $PROJECT_DIR"

# Execute command in a temporary docker container.
# We mount the project directory to /workspace/isaaclab_ext.
# The container runs as root to be able to chown the files.
docker run --rm \
    -v "$PROJECT_DIR:/workspace/isaaclab_ext:rw" \
    --entrypoint bash \
    "$IMAGE_NAME" \
    -c "${INNER_COMMAND}"

echo "[INFO] Permissions fixed successfully."
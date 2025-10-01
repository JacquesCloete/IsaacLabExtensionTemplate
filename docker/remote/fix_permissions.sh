#!/usr/bin/env bash

# This script runs a temporary Docker container to fix file permissions on the
# remote timestamped project directory.
#
# The arguments are:
# $1: Path to the timestamped project directory on the remote machine.
# $2: The image name (e.g., isaac-lab-ext-ext_template).
# $3: Path to the permanent logs directory on the remote machine.

# Exits if error occurs
set -e

#==
# Main
#==

TIMESTAMPED_PROJECT_DIR="$1"
IMAGE_NAME="$2"
REMOTE_LOGS_DIR="$3"

echo "[INFO] Using image: $IMAGE_NAME"
echo "[INFO] Fixing permissions for directory: $TIMESTAMPED_PROJECT_DIR"

# Check if the docker image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "[Error] The '$IMAGE_NAME' image does not exist on the remote!" >&2;
    exit 1
fi

# Get the host user's UID and GID to pass to the container
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# This is the command that will be executed inside the container.
# It runs `chown` to fix file permissions on the mounted directories.
INNER_COMMAND="chown -R ${HOST_UID}:${HOST_GID} /workspace/isaaclab /workspace/isaaclab_ext"

# Execute command in a temporary docker container.
# We mount the project directories and logs.
# The container runs as root to be able to chown the files.
docker run --rm \
    -v "$TIMESTAMPED_PROJECT_DIR/isaaclab:/workspace/isaaclab:rw" \
    -v "$TIMESTAMPED_PROJECT_DIR/isaaclab_ext:/workspace/isaaclab_ext:rw" \
    -v "$REMOTE_LOGS_DIR:/workspace/isaaclab_ext/logs:rw" \
    --entrypoint bash \
    "$IMAGE_NAME" \
    -c "${INNER_COMMAND}"

echo "[INFO] Permissions fixed successfully."
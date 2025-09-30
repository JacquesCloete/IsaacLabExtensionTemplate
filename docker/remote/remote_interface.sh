#!/usr/bin/env bash

#==
# Configurations
#==

# Exits if error occurs
set -e

# get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#==
# Functions
#==

# Checks if a docker image exists, otherwise prints warning and exists
check_image_exists() {
    image_name="$1"
    if ! docker image inspect $image_name &> /dev/null; then
        echo "[Error] The '$image_name' image does not exist!" >&2;
        echo "[Error] You might be able to build it with /IsaacLab[ExtensionName]/docker/container.py." >&2;
        exit 1
    fi
}

submit_job() {
    echo "[INFO] Arguments passed to job script ${@}"
    ssh $REMOTE_LOGIN "cd $REMOTE_PROJECT_DIR_TIMESTAMPED/isaaclab_ext/docker/remote && WANDB_API_KEY=${WANDB_API_KEY} bash run_docker.sh \"$REMOTE_PROJECT_DIR_TIMESTAMPED\" \"isaac-lab-ext-$suffix\" \"$job_id\" ${@}"
}

#==
# Main
#==

help() {
    echo -e "\nusage: $(basename "$0") [-h] <command> <args...> -- Utility for interfacing with a remote workstation."
    echo -e "\noptions:"
    echo -e "  -h              Display this help message."
    echo -e "\ncommands:"
    echo -e "  push [<suffix>]              Push the docker image to the remote workstation."
    echo -e "  job [<suffix>] <job_args...> Submit a job to the remote workstation."
    echo -e "  status                       Check the status of all running remote jobs."
    echo -e "  logs <job_id>                Follow the logs of a running job."
    echo -e "  cancel <job_id>              Cancel a running job."
    echo -e "  copy                         Copy the logs from the remote machine to the local machine."
    echo -e "  cleanup                      Remove all timestamped project directories from the remote machine."
    echo -e "\nwhere:"
    echo -e "  <suffix>  is the optional container name suffix. Defaults to 'ext_template'."
    echo -e "  <job_args> are optional arguments specific to the job command."
    echo -e "  <job_id>  is the ID of the job."
    echo -e "\n" >&2
}

# Parse options
while getopts ":h" opt; do
    case ${opt} in
        h )
            help
            exit 0
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            help
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Check for command
if [ $# -lt 1 ]; then
    echo "Error: Command is required." >&2
    help
    exit 1
fi

command=$1
shift
suffix="ext_template"

case $command in
    push)
        if [ $# -gt 1 ]; then
            echo "Error: Too many arguments for push command." >&2
            help
            exit 1
        fi
        [ $# -eq 1 ] && suffix=$1
        echo "Executing push command"
        [ -n "$suffix" ] && echo "Using suffix: $suffix"

        # Check if Docker image exists
        check_image_exists isaac-lab-ext-$suffix:latest
        # source env file to get remote login information
        source $SCRIPT_DIR/.env.remote

        echo "[INFO] Pushing docker image 'isaac-lab-ext-$suffix:latest' to '$REMOTE_LOGIN'..."
        docker save isaac-lab-ext-$suffix:latest | ssh $REMOTE_LOGIN 'docker load'
        echo "[INFO] Push complete."
        ;;
    job)
        if [ $# -ge 1 ]; then
            # check if the first argument is a suffix or a job argument
            if [[ $1 != -* ]] && [ -f "$SCRIPT_DIR/../.env.ext" ]; then
                suffix=$1
                shift
            fi
        fi
        job_args="$@"
        echo "[INFO] Executing job command"
        [ -n "$suffix" ] && echo -e "\tUsing suffix: $suffix"
        [ -n "$job_args" ] && echo -e "\tJob arguments: $job_args"
        source $SCRIPT_DIR/.env.remote

        # Get current date and time
        current_datetime=$(date +"%Y%m%d_%H%M%S")
        # Append current date and time to REMOTE_PROJECT_DIR to create unique directories
        REMOTE_PROJECT_DIR_TIMESTAMPED="${REMOTE_PROJECT_DIR}_${current_datetime}"

        # Define a unique job name for the container based on script and timestamp
        script_name=$(basename "$REMOTE_PYTHON_EXECUTABLE" .py)
        job_id="${script_name}-${current_datetime}"

        # make sure target directories exist in a single SSH login
        ssh $REMOTE_LOGIN "mkdir -p $REMOTE_PROJECT_DIR_TIMESTAMPED $REMOTE_PROJECT_DIR_TIMESTAMPED/isaaclab $REMOTE_PROJECT_DIR_TIMESTAMPED/isaaclab_ext"

        # Sync Isaac Lab code
        echo "[INFO] Syncing Isaac Lab code..."
        rsync -rh --exclude="*.git*" --exclude="logs" --exclude="outputs" --exclude="wandb" --filter=':- .dockerignore' $ISAACLAB_PATH/ $REMOTE_LOGIN:$REMOTE_PROJECT_DIR_TIMESTAMPED/isaaclab

        # Sync Isaac Lab Extension code
        echo "[INFO] Syncing Isaac Lab Extension code..."
        rsync -rh --exclude="*.git*" --exclude="logs" --exclude="outputs" --exclude="wandb" --filter=':- .dockerignore' $SCRIPT_DIR/../.. $REMOTE_LOGIN:$REMOTE_PROJECT_DIR_TIMESTAMPED/isaaclab_ext

        # execute job script on remote
        echo "[INFO] Executing job script..."
        # check whether the second argument is a suffix or a job argument
        submit_job $job_args
        echo "Submitted job with ID: $job_id"
        ;;
    status)
        if [ $# -ne 0 ]; then
            echo "Error: The 'status' command does not take any arguments." >&2
            help
            exit 1
        fi
        echo "[INFO] Checking status on remote workstation..."
        source $SCRIPT_DIR/.env.remote
        # Use the label to find all containers managed by this interface
        ssh $REMOTE_LOGIN "docker ps --filter 'label=managed-by=remote-interface'"
        ;;
    logs)
        if [ $# -ne 1 ]; then
            echo "Error: The 'logs' command requires a job ID." >&2
            help
            exit 1
        fi
        job_id=$1
        echo "[INFO] Tailing logs for job '$job_id'..."
        source $SCRIPT_DIR/.env.remote
        ssh -t $REMOTE_LOGIN "docker logs -f ${job_id}"
        ;;
    cancel)
        if [ $# -ne 1 ]; then
            echo "Error: The 'cancel' command requires a job ID." >&2
            help
            exit 1
        fi
        job_id=$1
        echo "[INFO] Cancelling job '$job_id'..."
        source $SCRIPT_DIR/.env.remote
        ssh $REMOTE_LOGIN "docker stop ${job_id}"
        ;;
    copy)
        if [ $# -gt 0 ]; then
            echo "Error: The 'copy' command does not take any arguments." >&2
            help
            exit 1
        fi
        echo "[INFO] Copying logs from the remote machine..."
        source $SCRIPT_DIR/.env.remote

        remote_log_path="$REMOTE_PROJECT_DIR/logs/"
        local_log_path="$SCRIPT_DIR/../../logs/"

        # Create local logs directory if it doesn't exist
        mkdir -p "$local_log_path"

        echo "[INFO] Syncing logs from '$REMOTE_LOGIN:$remote_log_path' to '$local_log_path'..."
        rsync -azv --info=progress2 "$REMOTE_LOGIN:$remote_log_path" "$local_log_path"
        echo "[INFO] Log synchronization complete."
        ;;
    cleanup)
        echo "[INFO] Executing cleanup command"
        source $SCRIPT_DIR/.env.remote
        base_project_dir_name=$(basename "$REMOTE_PROJECT_DIR")
        parent_dir=$(dirname "$REMOTE_PROJECT_DIR")

        echo "[INFO] Deleting directories matching '${base_project_dir_name}_*' in '$parent_dir' on '$REMOTE_LOGIN'..."
        ssh $REMOTE_LOGIN "find '$parent_dir' -mindepth 1 -maxdepth 1 -type d -name '${base_project_dir_name}_*' -exec rm -rf {} +"
        echo "[INFO] Cleanup complete."
        ;;
    *)
        echo "Error: Invalid command: $command" >&2
        help
        exit 1
        ;;
esac
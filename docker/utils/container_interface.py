# Copyright (c) 2022-2025, The Isaac Lab Project Developers (https://github.com/isaac-sim/IsaacLab/blob/main/CONTRIBUTORS.md).
# All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

from __future__ import annotations

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

from .state_file import StateFile


class ContainerInterface:
    """A helper class for managing Isaac Lab containers."""

    def __init__(
        self,
        context_dir: Path,
        suffix: str = "ext_template",
        yamls: list[str] | None = None,
        envs: list[str] | None = None,
        statefile: StateFile | None = None,
    ):
        """Initialize the container interface with the given parameters.

        Args:
            context_dir: The context directory for Docker operations.
            suffix: Docker image and container name suffix.  Defaults to "ext_template". A hyphen is inserted before the 
            suffix if the suffix does not already include a hyphen. For example, if "custom" is passed to suffix, then
            the produced docker image and container will be named ``isaac-lab-ext-custom``.
            yamls: A list of yaml files to extend ``docker-compose.yaml`` settings. These are extended in the order
                they are provided.
            envs: A list of environment variable files to extend the ``.env.ext`` file. These are extended in the order
                they are provided.
            statefile: An instance of the :class:`Statefile` class to manage state variables. Defaults to None, in
                which case a new configuration object is created by reading the configuration file at the path
                ``context_dir/.container.cfg``.
        """
        # set the context directory
        self.context_dir = context_dir

        # create a state-file if not provided
        # the state file is a manager of run-time state variables that are saved to a file
        if statefile is None:
            self.statefile = StateFile(path=self.context_dir / ".container.cfg")
        else:
            self.statefile = statefile

        # set the profile and container name
        self.profile = "ext"

        # set the docker image and container name suffix
        assert suffix is not None and suffix != "", "Suffix must not be None or an empty string"
        # insert a hyphen before the suffix if it doesn't already start with a hyphen
        if not suffix.startswith("-"):
            self.suffix = f"-{suffix}"
        else:
            self.suffix = suffix

        self.container_name = f"isaac-lab-{self.profile}{self.suffix}"
        self.image_name = f"isaac-lab-{self.profile}{self.suffix}:latest"

        # keep the environment variables from the current environment,
        # except make sure that the docker name suffix is set from the script
        self.environ = os.environ.copy()
        self.environ["DOCKER_NAME_SUFFIX"] = self.suffix

        # resolve the image extension through the passed yamls and envs
        self._resolve_image_extension(yamls, envs)
        # load the environment variables from the .env files
        self._parse_dot_vars()

    """
    Operations.
    """

    def is_container_running(self) -> bool:
        """Check if the container is running.

        Returns:
            True if the container is running, otherwise False.
        """
        status = subprocess.run(
            ["docker", "container", "inspect", "-f", "{{.State.Status}}", self.container_name],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
        return status == "running"

    def does_image_exist(self) -> bool:
        """Check if the Docker image exists.

        Returns:
            True if the image exists, otherwise False.
        """
        result = subprocess.run(["docker", "image", "inspect", self.image_name], capture_output=True, text=True)
        return result.returncode == 0

    def start(self):
        """Build and start the Docker container using the Docker compose command."""
        print(
            f"[INFO] Building the docker image and starting the container '{self.container_name}' in the"
            " background...\n"
        )
        # Check if the container history file exists
        container_history_file = self.context_dir / ".isaac-lab-ext-docker-history"
        if not container_history_file.exists():
            # Create the file with sticky bit on the group
            container_history_file.touch(mode=0o2644, exist_ok=True)

        # build the image for the ext profile if not running ext (up will build ext already if profile is ext)
        if self.profile != "ext":
            subprocess.run(
                [
                    "docker",
                    "compose",
                    "--file",
                    "docker-compose.yaml",
                    "--env-file",
                    ".env.ext",
                    "build",
                    "isaac-lab-ext",
                ],
                check=False,
                cwd=self.context_dir,
                env=self.environ,
            )

        # build the image for the profile
        subprocess.run(
            ["docker", "compose"]
            + self.add_yamls
            + self.add_profiles
            + self.add_env_files
            + ["up", "--detach", "--build", "--remove-orphans"],
            check=False,
            cwd=self.context_dir,
            env=self.environ,
        )

    def enter(self):
        """Enter the running container by executing a bash shell.

        Raises:
            RuntimeError: If the container is not running.
        """
        if self.is_container_running():
            print(f"[INFO] Entering the existing '{self.container_name}' container in a bash session...\n")
            subprocess.run([
                "docker",
                "exec",
                "--interactive",
                "--tty",
                *(["-e", f"DISPLAY={os.environ['DISPLAY']}"] if "DISPLAY" in os.environ else []),
                f"{self.container_name}",
                "bash",
            ])
        else:
            raise RuntimeError(f"The container '{self.container_name}' is not running.")
        
    def job(self, job_args: list[str]):
        """Run a command in the container in the background.

        This uses `docker exec` to start a new process inside the running container.
        The process is run in the background, and its PID is stored in a file
        in the container's `/tmp` directory for management.

        Args:
            job_args: A list of arguments for the job. The first argument is typically
                the path to the python script to execute.

        Raises:
            RuntimeError: If the container is not running.
            ValueError: If no job arguments are provided.
        """
        if not self.is_container_running():
            raise RuntimeError(
                f"The container '{self.container_name}' is not running. Please start it first with the 'start' command."
            )
        if not job_args:
            raise ValueError("No job arguments provided. You must specify a script to run.")
        
        # Check if the script file exists on the host
        script_path = self.context_dir.parent / job_args[0]
        if not script_path.is_file():
            raise FileNotFoundError(
                f"The specified script does not exist or is not a file: {script_path}\n"
                f"Please provide a valid path to a script within the project."
            )

        # Define a name for the job based on the script name
        script_name = Path(job_args[0]).stem
        time_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        job_name = f"{script_name}-{time_str}"
        pid_file = f"/tmp/{job_name}.pid"

        print(f"[INFO] Submitting job '{job_name}' to container '{self.container_name}'...")

        # Construct the command to be run inside the container
        # This command starts the python script in the background, and saves its PID to a file.
        docker_isaac_lab_path = self.dot_vars["DOCKER_ISAACLAB_EXT_PATH"]
        command_to_run = (
            f"cd {docker_isaac_lab_path} && "
            f"nohup /isaac-sim/python.sh {' '.join(job_args)} > /tmp/{job_name}.log 2>&1 & "
            f"echo $! > {pid_file}"
        )

        # Execute the command using 'docker exec'
        subprocess.run(
            ["docker", "exec", self.container_name, "bash", "-c", command_to_run],
            check=True,
        )
        print(f"[INFO] Successfully submitted job. Use 'status' to check and 'cancel {job_name}' to stop.")

    def status(self, job_name: str | None = None):
        """Check the status of running jobs within the container.

        Args:
            job_name: If provided, checks the status of a specific job. Otherwise, lists all running jobs.

        Raises:
            RuntimeError: If the container is not running.
        """
        if not self.is_container_running():
            raise RuntimeError(f"The container '{self.container_name}' is not running.")

        print(f"[INFO] Checking job status in container '{self.container_name}'...")
        if job_name:
            command_to_run = f"if [ -f /tmp/{job_name}.pid ] && ps -p $(cat /tmp/{job_name}.pid) > /dev/null; then echo 'Job {job_name} is running.'; else echo 'Job {job_name} is not running or has completed.'; fi"
        else:
            command_to_run = (
                "echo 'Running jobs:'; "
                "for f in /tmp/*.pid; do "
                "  if [ -e \"$f\" ]; then "
                "    pid=$(cat \"$f\"); "
                "    if ps -p \"$pid\" > /dev/null; then "
                "      echo \"  - $(basename \"$f\" .pid)\"; "
                "    else "
                "      rm \"$f\"; "
                "    fi; "
                "  fi; "
                "done"
            )
        subprocess.run(["docker", "exec", self.container_name, "bash", "-c", command_to_run], check=True)

    def cancel(self, job_name: str):
        """Cancel a running job within the container.

        Args:
            job_name: The name of the job to cancel.

        Raises:
            RuntimeError: If the container is not running.
        """
        if not self.is_container_running():
            raise RuntimeError(f"The container '{self.container_name}' is not running.")

        print(f"[INFO] Attempting to cancel job '{job_name}' in container '{self.container_name}'...")
        pid_file = f"/tmp/{job_name}.pid"
        log_file = f"/tmp/{job_name}.log"
        command_to_run = (
            f"if [ -f {pid_file} ]; then "
            f"  PGID=$(ps -o pgid= $(cat {pid_file}) | grep -o '[0-9]*');"
            f"  kill -- -$PGID; "
            f"  rm {pid_file} {log_file}; "
            f"  echo 'Successfully cancelled job {job_name}.'; "
            f"else "
            f"  echo 'Could not find job {job_name}. It may have already completed or been cancelled.'; "
            f"fi"
        )
        subprocess.run(["docker", "exec", self.container_name, "bash", "-c", command_to_run], check=True)

    def logs(self, job_name: str):
        """Follow the logs of a running job within the container.

        Args:
            job_name: The name of the job to follow.

        Raises:
            RuntimeError: If the container is not running.
        """
        if not self.is_container_running():
            raise RuntimeError(f"The container '{self.container_name}' is not running.")

        print(f"[INFO] Following logs for job '{job_name}' in container '{self.container_name}'...")
        print("[INFO] Press Ctrl+C to stop following.")
        log_file = f"/tmp/{job_name}.log"

        # Command to check if log file exists and then tail it
        command_to_run = (
            f"if [ -f {log_file} ]; then "
            f"  tail -f {log_file}; "
            f"else "
            f"  echo 'Log file for job {job_name} not found. The job may not have started or has been cancelled.'; "
            f"fi"
        )

        # We use -it to allow `tail -f` to be interrupted with Ctrl+C
        subprocess.run(
            ["docker", "exec", "-it", self.container_name, "bash", "-c", command_to_run],
            check=False,
        )

    def stop(self):
        """Stop the running container using the Docker compose command.

        Raises:
            RuntimeError: If the container is not running.
        """
        if self.is_container_running():
            print(f"[INFO] Stopping the launched docker container '{self.container_name}'...\n")
            subprocess.run(
                ["docker", "compose"] + self.add_yamls + self.add_profiles + self.add_env_files + ["down", "--volumes"],
                check=False,
                cwd=self.context_dir,
                env=self.environ,
            )
        else:
            raise RuntimeError(f"Can't stop container '{self.container_name}' as it is not running.")

    def copy(self, output_dir: Path | None = None):
        """Copy artifacts from the running container to the host machine.

        Args:
            output_dir: The directory to copy the artifacts to. Defaults to None, in which case
                the context directory is used.

        Raises:
            RuntimeError: If the container is not running.
        """
        if self.is_container_running():
            print(f"[INFO] Copying artifacts from the '{self.container_name}' container...\n")
            if output_dir is None:
                output_dir = self.context_dir

            # create a directory to store the artifacts
            output_dir = output_dir.joinpath("artifacts")
            if not output_dir.is_dir():
                output_dir.mkdir()

            # define dictionary of mapping from docker container path to host machine path
            docker_isaac_lab_path = Path(self.dot_vars["DOCKER_ISAACLAB_EXT_PATH"])
            artifacts = {
                docker_isaac_lab_path.joinpath("logs"): output_dir.joinpath("logs"),
                docker_isaac_lab_path.joinpath("docs/_build"): output_dir.joinpath("docs"),
                docker_isaac_lab_path.joinpath("data_storage"): output_dir.joinpath("data_storage"),
            }
            # print the artifacts to be copied
            for container_path, host_path in artifacts.items():
                print(f"\t -{container_path} -> {host_path}")
            # remove the existing artifacts
            for path in artifacts.values():
                shutil.rmtree(path, ignore_errors=True)

            # copy the artifacts
            for container_path, host_path in artifacts.items():
                subprocess.run(
                    [
                        "docker",
                        "cp",
                        f"isaac-lab-{self.profile}{self.suffix}:{container_path}/",
                        f"{host_path}",
                    ],
                    check=False,
                )
            print("\n[INFO] Finished copying the artifacts from the container.")
        else:
            raise RuntimeError(f"The container '{self.container_name}' is not running.")

    def config(self, output_yaml: Path | None = None):
        """Process the Docker compose configuration based on the passed yamls and environment files.

        If the :attr:`output_yaml` is not None, the configuration is written to the file. Otherwise, it is printed to
        the terminal.

        Args:
            output_yaml: The path to the yaml file where the configuration is written to. Defaults
                to None, in which case the configuration is printed to the terminal.
        """
        print("[INFO] Configuring the passed options into a yaml...\n")

        # resolve the output argument
        if output_yaml is not None:
            output = ["--output", output_yaml]
        else:
            output = []

        # run the docker compose config command to generate the configuration
        subprocess.run(
            ["docker", "compose"] + self.add_yamls + self.add_profiles + self.add_env_files + ["config"] + output,
            check=False,
            cwd=self.context_dir,
            env=self.environ,
        )

    """
    Helper functions.
    """

    def _resolve_image_extension(self, yamls: list[str] | None = None, envs: list[str] | None = None):
        """
        Resolve the image extension by setting up YAML files, profiles, and environment files for the Docker compose command.

        Args:
            yamls: A list of yaml files to extend ``docker-compose.yaml`` settings. These are extended in the order
                they are provided.
            envs: A list of environment variable files to extend the ``.env.ext`` file. These are extended in the order
                they are provided.
        """
        self.add_yamls = ["--file", "docker-compose.yaml"]
        self.add_profiles = ["--profile", f"{self.profile}"]
        self.add_env_files = ["--env-file", ".env.ext"]

        # extend env file based on profile
        if self.profile != "ext":
            self.add_env_files += ["--env-file", f".env.{self.profile}"]

        # extend the env file based on the passed envs
        if envs is not None:
            for env in envs:
                self.add_env_files += ["--env-file", env]

        # extend the docker-compose.yaml based on the passed yamls
        if yamls is not None:
            for yaml in yamls:
                self.add_yamls += ["--file", yaml]

    def _parse_dot_vars(self):
        """Parse the environment variables from the .env files.

        Based on the passed ".env" files, this function reads the environment variables and stores them in a dictionary.
        The environment variables are read in order and overwritten if there are name conflicts, mimicking the behavior
        of Docker compose.
        """
        self.dot_vars: dict[str, Any] = {}

        # check if the number of arguments is even for the env files
        if len(self.add_env_files) % 2 != 0:
            raise RuntimeError(
                "The parameters for env files are configured incorrectly. There should be an even number of arguments."
                f" Received: {self.add_env_files}."
            )

        # read the environment variables from the .env files
        for i in range(1, len(self.add_env_files), 2):
            with open(self.context_dir / self.add_env_files[i]) as f:
                self.dot_vars.update(dict(line.strip().split("=", 1) for line in f if "=" in line))

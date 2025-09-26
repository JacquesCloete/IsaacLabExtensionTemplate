#!/usr/bin/env python3

# Copyright (c) 2022-2025, The Isaac Lab Project Developers (https://github.com/isaac-sim/IsaacLab/blob/main/CONTRIBUTORS.md).
# All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

import argparse
import shutil
from pathlib import Path

from utils import ContainerInterface, x11_utils


def parse_cli_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Utility for using Docker with Isaac Lab Extensions.")

    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument(
        "suffix",
        nargs="?",
        default="template",
        help=(
            "Docker image and container name suffix. A hyphen is inserted before the suffix if it does not already "
            "include a hyphen. For example, with suffix 'dev', the container will be named 'isaac-lab-ext-dev'."
        ),
    )
    parent_parser.add_argument(
        "--files",
        nargs="*",
        default=None,
        help=(
            "Allows additional '.yaml' files to be passed to the docker compose command. These files will be merged"
            " with 'docker-compose.yaml' in their provided order."
        ),
    )
    parent_parser.add_argument(
        "--env-files",
        nargs="*",
        default=None,
        help=(
            "Allows additional '.env' files to be passed to the docker compose command. These files will be merged with"
            " '.env.ext' in their provided order."
        ),
    )

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser(
        "start",
        help="Build the docker image and create the container in detached mode.",
        parents=[parent_parser],
    )
    subparsers.add_parser(
        "enter", help="Begin a new bash process within an existing container.", parents=[parent_parser]
    )
    subparsers.add_parser(
        "copy", help="Copy build and logs artifacts from the container to the host machine.", parents=[parent_parser]
    )
    subparsers.add_parser("stop", help="Stop the docker container and remove it.", parents=[parent_parser])

    args = parser.parse_args()
    return args


def main(args: argparse.Namespace):
    """Main function for the Docker utility."""
    if not shutil.which("docker"):
        raise RuntimeError(
            "Docker is not installed! Please check the 'Docker Guide' for instruction: "
            "https://isaac-sim.github.io/IsaacLab/source/deployment/docker.html"
        )

    ci = ContainerInterface(
        context_dir=Path(__file__).resolve().parent,
        suffix=args.suffix,
        yamls=args.files,
        envs=args.env_files,
    )

    print(f"[INFO] Using container suffix: {ci.suffix}")
    if args.command == "start":
        x11_outputs = x11_utils.x11_check(ci.statefile)
        if x11_outputs is not None:
            (x11_yaml, x11_envar) = x11_outputs
            ci.add_yamls += x11_yaml
            ci.environ.update(x11_envar)
        ci.start()
    elif args.command == "enter":
        x11_utils.x11_refresh(ci.statefile)
        ci.enter()
    elif args.command == "copy":
        ci.copy()
    elif args.command == "stop":
        ci.stop()
        x11_utils.x11_cleanup(ci.statefile)
    else:
        raise RuntimeError(f"Invalid command provided: {args.command}. Please check the help message.")


if __name__ == "__main__":
    args_cli = parse_cli_args()
    main(args_cli)
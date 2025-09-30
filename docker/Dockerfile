ARG ISAACLAB_BASE_IMAGE_ARG=isaac-lab-base

# we use the basic isaaclab image as the base
FROM ${ISAACLAB_BASE_IMAGE_ARG} AS base

ARG DOCKER_ISAACLAB_EXT_PATH_ARG
ENV DOCKER_ISAACLAB_EXT_PATH=${DOCKER_ISAACLAB_EXT_PATH_ARG}

USER root

# Copy the Isaac Lab Extension directory (files to exclude are defined in .dockerignore)
COPY ../ ${DOCKER_ISAACLAB_EXT_PATH}

# # Install whatever you need as additional dependencies.
RUN bash -i -c "source ${HOME}/.bashrc && \
    cd ${DOCKER_ISAACLAB_EXT_PATH}/source/ext_template && \
    pip install -e ."

# make working directory as the Isaac Lab extension directory
# this is the default directory when the container is run
WORKDIR ${DOCKER_ISAACLAB_EXT_PATH}

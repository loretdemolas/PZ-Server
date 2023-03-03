#non root base image

ARG BASE_IMAGE="docker.io/renegademaster/steamcmd-minimal:latest"
ARG UID=1000
ARG GID=${UID}
ARG RUN_USER=steam

FROM ${BASE_IMAGE}
ARG UID
ARG GID
ARG RUN_USER    

#becoome root do install packacges
USER 0:0

# Install Python, and take ownership of rcon binary
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-minimal iputils-ping tzdata \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN mkhomedir_helper "${RUN_USER}" 
RUN chown -R ${UID}:${GID} /home/${RUN_USER}/

USER ${RUN_USER}

# Copy the source files
COPY --chown=${RUN_USER} edit_server_config.py /home/steam/
COPY --chown=${RUN_USER} install_server.scmd /home/steam/
COPY --chown=${RUN_USER} run_server.sh /home/steam/

# Run the setup script
ENTRYPOINT ["/bin/bash", "/home/steam/run_server.sh"]
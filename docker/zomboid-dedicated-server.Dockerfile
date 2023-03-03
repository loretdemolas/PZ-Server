#non root base image

ARG BASE_IMAGE="docker.io/renegademaster/steamcmd-minimal:latest"
ARG UID=1000
ARG GID=${UID}
ARG RUN_USER=steam

FROM ${BASE_IMAGE}
ARG UID
ARG GID
ARG RUN_USER    

#becoome root to install packacges and set up directory
USER 0:0

# Install Python, take ownership of rcon binary, create homedir, create game dir,.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-minimal iputils-ping tzdata \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && mkhomedir_helper "${RUN_USER}" \
    && mkdir -p /home/steam/ZomboidDedicatedServer \
    && mkdir -p /home/steam/Zomboid/

# Copy the scripts files
COPY --chown=${RUN_USER} edit_server_config.py install_server.scmd run_server.sh /home/steam/

#set permission for home directory to 1000:1000
RUN chown -R  ${UID}:${GID} /home/${RUN_USER}/ \
    && chown -R 1777 /tmp

#move into workdir
WORKDIR /home/steam/

#Change perms for scripts

RUN chmod a+x edit_server_config.py install_server.scmd

#change back to user
USER ${RUN_USER}

# Run the setup script
ENTRYPOINT ["/bin/bash", "/home/steam/run_server.sh"]





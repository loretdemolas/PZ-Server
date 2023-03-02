ARG BASE_IMAGE="docker.io/renegademaster/steamcmd-minimal:2.0.0"

FROM ${BASE_IMAGE}
    

# Copy the source files
COPY edit_server_config.py /home/steam/
COPY install_server.scmd /home/steam/
COPY run_server.sh /home/steam/

# Install Python, and take ownership of rcon binary
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-minimal iputils-ping tzdata \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN chmod +rwx /home/steam

# Run the setup script
ENTRYPOINT ["/bin/bash", "/home/steam/run_server.sh"]
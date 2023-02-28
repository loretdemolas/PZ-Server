ARG BASE_IMAGE="docker.io/renegademaster/steamcmd-minimal:1.1.2"


FROM ${BASE_IMAGE}


# Copy the source files
COPY src /home/steam/

# Install Python, and take ownership of rcon binary
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-minimal iputils-ping tzdata \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN chmod +rwx /home/steam/run_server.sh

# Run the setup script
ENTRYPOINT ["bin/bash", "/home/steam/run_server.sh"]
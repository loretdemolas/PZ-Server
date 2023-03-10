# Set to `-x` for Debug logging
set +x -o pipefail



# Handle shutting down the server, with optional RCON quit for graceful shutdown
function shutdown() {
    if [[ "$RCON_ENABLED" == "true" ]]; then
        printf "\n### Sending RCON quit command\n"
        rcon --address "$BIND_IP:$RCON_PORT" --password "$RCON_PASSWORD" quit
    else
        printf "\n### RCON not enabled: cannot issue quit command.\nSending SIGTERM...\n"
        pkill -P $$
    fi
}

# Start the Server
function start_server() {
    printf "\n### Starting Project Zomboid Server...\n"
    timeout "$TIMEOUT" "$BASE_GAME_DIR"/start-server.sh \
        -cachedir="$CONFIG_DIR" \
        -adminusername "$ADMIN_USERNAME" \
        -adminpassword "$ADMIN_PASSWORD" \
        -ip "$BIND_IP" -port "$DEFAULT_PORT" \
        -servername "$SERVER_NAME" \
        -steamvac "$STEAM_VAC" "$USE_STEAM" &
        server_pid=$!
    wait $server_pid

    # NOTE(ramielrowe): Apparently the first wait will return immediately after
    #   the trap handler returns. The server can take a couple seconds to fully
    #   shutdown after the `quit` command. So, call wait once more to ensure
    #   the server is fully stopped.
    wait $server_pid

    printf "\n### Project Zomboid Server stopped.\n"
}


function apply_postinstall_config() {
    printf "\n### Applying Post Install Configuration...\n"
    
    # Set the Autosave Interval
    "$EDIT_CONFIG" "$SERVER_CONFIG" "SaveWorldEveryMinutes" "$AUTOSAVE_INTERVAL"\
        || fail_with_reason "Could not apply post-install configuration to file [${SERVER_CONFIG}]"

    # Set the default Server Port
    "$EDIT_CONFIG" "$SERVER_CONFIG" "DefaultPort" "$DEFAULT_PORT"

    # Set the default extra UDP Port
    "$EDIT_CONFIG" "$SERVER_CONFIG" "UDPPort" "$UDP_PORT"

    # Set the Max Players
    "$EDIT_CONFIG" "$SERVER_CONFIG" "MaxPlayers" "$MAX_PLAYERS"

    # Set the Mod names
    "$EDIT_CONFIG" "$SERVER_CONFIG" "Mods" "$MOD_NAMES"

    # Set the Map names
    "$EDIT_CONFIG" "$SERVER_CONFIG" "Map" "$MAP_NAMES"

    # Set the Mod Workshop IDs
    "$EDIT_CONFIG" "$SERVER_CONFIG" "WorkshopItems" "$MOD_WORKSHOP_IDS"

    # Set the Pause on Empty Server
    "$EDIT_CONFIG" "$SERVER_CONFIG" "PauseEmpty" "$PAUSE_ON_EMPTY"

    # Set the Server Publicity status
    "$EDIT_CONFIG" "$SERVER_CONFIG" "Open" "$PUBLIC_SERVER"

    # Set the Server RCON Password
    "$EDIT_CONFIG" "$SERVER_CONFIG" "RCONPassword" "$RCON_PASSWORD"

    # Set the Server RCON Port
    "$EDIT_CONFIG" "$SERVER_CONFIG" "RCONPort" "$RCON_PORT"

    # Set the Server Name
    "$EDIT_CONFIG" "$SERVER_CONFIG" "PublicName" "$SERVER_NAME"

    # Set the Server Password
    "$EDIT_CONFIG" "$SERVER_CONFIG" "Password" "$SERVER_PASSWORD"

    #Set the Serer ResetID
    "$EDIT_CONFIG" "$SERVER_CONFIG" "ResetID" "$RESETID"

    # Set the maximum amount of RAM for the JVM
    sed -i "s/-Xmx.*/-Xmx${MAX_RAM}\",/g" "${SERVER_VM_CONFIG}"\
      || fail_with_reason "Could not apply post-install configuration to file [${SERVER_VM_CONFIG}]"

    # Set the GC for the JVM (advanced, some crashes can be fixed with a different GC algorithm)
    sed -i "s/-XX:+Use.*/-XX:+Use${GC_CONFIG}\",/g" "${SERVER_VM_CONFIG}"

    printf "\n### Post Install Configuration applied.\n"
}

# Test if this is the the first time the server has run
function test_first_run() {
    printf "\n### Checking if this is the first run...\n"

    if [[ ! -f "$SERVER_CONFIG" ]] || [[ ! -f "$SERVER_RULES_CONFIG" ]]; then
        printf "\n### This is the first run.\nStarting server for %s seconds\n" "$TIMEOUT"
        start_server
        TIMEOUT=0
    else
        printf "\n### This is not the first run.\n"
        TIMEOUT=0
    fi

    printf "\n### First run check complete.\n"
}

# Update the server
function update_server() {
    printf "\n### Updating Project Zomboid Server...\n"

    steamcmd.sh +runscript "$STEAM_INSTALL_FILE"

     if [[ ! -f "$BASE_GAME_DIR"/start-server.sh ]]; then
      fail_with_reason "Could not install/update game server using install file [${STEAM_INSTALL_FILE}]"
    fi

    printf "\n### Project Zomboid Server updated.\n"
}

# Apply user configuration to the server
function apply_preinstall_config() {
    printf "\n### Applying Pre Install Configuration...\n"

    chown -R "$(id -u):$(id -g)" "${BASE_GAME_DIR}" "${CONFIG_DIR}" \
      || fail_with_reason "Could not modify permissions on the required game directories: [${BASE_GAME_DIR}] and [${CONFIG_DIR}]"
    
    # Set the selected game version
    sed -i "s/beta .* /beta $GAME_VERSION /g" "$STEAM_INSTALL_FILE"

    printf "\n### Pre Install Configuration applied.\n"
}

# Set variables for use in the script
function set_variables() {
    printf "\n### Setting variables...\n"

    TIMEOUT="60"
    EDIT_CONFIG="/home/steam/edit_server_config.py"
    STEAM_INSTALL_FILE="/home/steam/install_server.scmd"
    BASE_GAME_DIR="/home/steam/ZomboidDedicatedServer"
    CONFIG_DIR="/home/steam/Zomboid"

    # Set the Server Admin Password variable
    ADMIN_USERNAME=${ADMIN_USERNAME:-"admin"}

    # Set the Server Admin Password variable
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-"changeme"}

    # Set the Autosave Interval variable
    AUTOSAVE_INTERVAL=${AUTOSAVE_INTERVAL:-"5"}

    # Set the IP address variable
    # NOTE: Project Zomboid cannot handle the IN_ANY address
    if [[ -z "$BIND_IP" ]] || [[ "$BIND_IP" == "0.0.0.0" ]]; then
        BIND_IP=($(hostname -I))
        BIND_IP="${BIND_IP[0]}"
    else
        BIND_IP="$BIND_IP"
    fi
    echo "$BIND_IP" > "$CONFIG_DIR/ip.txt"

    # Set the IP Game Port variable
    DEFAULT_PORT=${DEFAULT_PORT:-"16261"}

    # Set the extra UDP Game Port variable
    UDP_PORT=${UDP_PORT:-"16262"}

    # Set the game version variable
    GAME_VERSION=${GAME_VERSION:-"public"}

    # Set the Max Players variable
    MAX_PLAYERS=${MAX_PLAYERS:-"16"}

    # Set the Maximum RAM variable
    MAX_RAM=${MAX_RAM:-"4096m"}

    # Sets GC
    GC_CONFIG=${GC_CONFIG:-"ZGC"}

    # Set the Mods to use from workshop
    MOD_NAMES=${MOD_NAMES:-""}
    MOD_WORKSHOP_IDS=${MOD_WORKSHOP_IDS:-""}

    # Set the Maps to use
    MAP_NAMES=${MAP_NAMES:-"Muldraugh, KY"}

    # Set the Pause on Empty variable
    PAUSE_ON_EMPTY=${PAUSE_ON_EMPTY:-"true"}

    # Set the Server Publicity variable
    PUBLIC_SERVER=${PUBLIC_SERVER:-"true"}

    # Set the IP Query Port variable
    DEFAULT_PORT=${DEFAULT_PORT:-"16261"}

    # Set the Server name variable
    SERVER_NAME=${SERVER_NAME:-"servertest"}

    # Set the Server Password variable
    SERVER_PASSWORD=${SERVER_PASSWORD:-""}

    # Set Steam VAC Protection variable
    STEAM_VAC=${STEAM_VAC:-"true"}

    #Set the Server ResetID
    RESETID=${RESETID:-"4017086"}

    # Set server type variable
    if [[ -z "$USE_STEAM" ]] || [[ "$USE_STEAM" == "true" ]]; then
        USE_STEAM=""
    else
        USE_STEAM="-nosteam"
    fi

    # Set RCON configuration
    if [[ -z "$RCON_PORT" ]] || [[ "$RCON_PORT" == "0" ]]; then
        RCON_ENABLED="false"
    else
        RCON_ENABLED="true"
        RCON_PORT=${RCON_PORT:-"27015"}
        RCON_PASSWORD=${RCON_PASSWORD:-"changeme_rcon"}
    fi

    SERVER_CONFIG="$CONFIG_DIR/Server/$SERVER_NAME.ini"
    SERVER_VM_CONFIG="$BASE_GAME_DIR/ProjectZomboid64.json"
    SERVER_RULES_CONFIG="$CONFIG_DIR/Server/${SERVER_NAME}_SandboxVars.lua"
}

# fail_with_reason prints an error to STDERR and exits the script.
fail_with_reason() {
  c_clr="\x1b[0m"
  c_it_gre="\x1b[3;32m"
  c_red="\x1b[0;31m"
  c_ul_yel="\x1b[4;33m"

  printf "\n${c_ul_yel}Error encountered:${c_red} [%s]${c_clr}\n" "$1" 1>&2

  # If Debug is not empty and not set to FALSE
  if [[ -n "${DEBUG}" ]] && [[ "${DEBUG}" != "FALSE" ]] && [[ "${DEBUG}" != "false" ]]; then
    # shellcheck disable=SC2059
    printf "\n${c_it_gre}Start DEBUG info\n\n${c_clr}" 1>&2

    printf "${c_ul_yel}User:${c_clr} [%s]\n" "$(whoami)" 1>&2
    printf "${c_ul_yel}Groups:${c_clr} [%s]\n" "$(groups)" 1>&2
    printf "${c_ul_yel}User ID:${c_clr} [%s]\n" "$(id -u)" 1>&2
    printf "${c_ul_yel}Group ID:${c_clr} [%s]\n\n" "$(id -g)" 1>&2

    printf "${c_ul_yel}Can SUDO?:${c_clr} [%s]\n\n" "$(if [[ $(sudo -v 2>/dev/null) ]]; then echo "YES"; else echo "NO"; fi)" 1>&2

    printf "${c_ul_yel}CPU Info:${c_clr} \n[\n%s\n]\n\n" "$(lscpu | grep -iE "Architecture")" 1>&2
    printf "${c_ul_yel}Environment variables:${c_clr} \n[\n%s\n]\n\n" "$(env | sort)" 1>&2

    printf "${c_ul_yel}Directory listing:${c_clr} \n[\n%s\n]\n\n" "$(ls -lAuhF /home/steam/)" 1>&2
    printf "${c_ul_yel}Directory listing with IDs:${c_clr} \n[\n%s\n]\n\n" "$(ls -lAuhFn /home/steam/)" 1>&2

    printf "${c_ul_yel}ZomboidConfig listing:${c_clr} \n[\n%s\n]\n\n" "$(ls -lAuhF ${CONFIG_DIR})" 1>&2
    printf "${c_ul_yel}ZomboidDedicatedServer listing:${c_clr} \n[\n%s\n]\n\n" "$(ls -lAuhF ${BASE_GAME_DIR})" 1>&2

    # shellcheck disable=SC2059
    printf "${c_it_gre}End DEBUG info\n\n${c_clr}" 1>&2
  fi

  # shellcheck disable=SC2059
  printf "${c_ul_yel}Exiting program...${c_clr}\n" 1>&2

  exit 1
}

## Main
set_variables
apply_preinstall_config
update_server
test_first_run
apply_postinstall_config

# Intercept termination signals to stop the server gracefully
trap shutdown SIGTERM SIGINT

start_server
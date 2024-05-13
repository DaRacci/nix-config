{ writeShellApplication
, openssh
, lib
}: writeShellApplication {
  name = "copy-to-proxmox";

  runtimeInputs = [ openssh ];

  text = ''
    # Set sane defaults
    ROOT_DISK_SIZE=8
    MEMORY=2048
    CPU_CORES=2
    NAME=""
    ID=""

    get_user_input() {
      local prompt=''${1}
      local default=''${!2}
      local nullable=''${3:-true}

      while true; do
        if [ -z "$default" ]; then
          read -p "Enter $prompt: " input
        else
          read -p "Enter $prompt (default: $default): " input
        fi

        if [ -z "$input" ]; then
          if [ "$nullable" = false ]; then
            echo "Input cannot be empty."
            continue
          fi

          echo "$default"
          break
        else
          echo "$input"
          break
        fi
      done
    }

    # Get user input for root disk size, memory, and CPU cores
    ROOT_DISK_SIZE=$(get_user_input "root disk size" ROOT_DISK_SIZE)
    MEMORY=$(get_user_input "memory" MEMORY)
    CPU_CORES=$(get_user_input "CPU cores" CPU_CORES)

    # Ask for container name
    NAME=$(get_user_input "name" null false)

    # Get the next available ID
    ID=$(pvesh get /cluster/nextid)
    TZ=$(cat /etc/timezone)

    # Verify that the template exists
    TEMPLATE=/var/lib/vz/template/cache/nixos-system-x86_64-linux.tar.xz
    if [ ! -f "$TEMPLATE" ]; then
      echo "Template not found at $TEMPLATE. Exiting."
      echo "Create the template by running the following command and uploading it to the Proxmox server:"
      echo "nix run github:nix-community/nixos-generators -- --format proxmox-lxc"
      exit 1
    fi

    FEATURES="nesting=1"

    # Create the container
    pct create $ID $TEMPLATE \
      --hostname "$NAME" --memory "$MEMORY" \
      -net0 name=eth0,bridge=vmbr0,ip=dhcp,type=veth --storage local-zfs \
      -rootfs local-zfs:"$ROOT_DISK_SIZE" --mp0 local-zfs:16,mp=/nix/store \
      -unprivileged 1 --cmode console --arch amd64 --start 0 --onboot 1 \
      --features "$FEATURES"

    # Verify that the container was created successfully
    if [ $? -eq 0 ]; then
      echo "Container created successfully!"
    else
      echo "Error creating container. Check the output for more information."
    fi

    # TODO :: Start with another command to fix timeout
    # TODO :: Run init for flake and prompt for SSH Keys
    # TODO :: Ask what flake target this is
    # TODO :: Auto do all that flake stuff
  '';

  meta = {
    description = "Copy a hosts output to proxmox templates";
    license = lib.licenses.MIT;
    platforms = lib.platforms.linux;
    maintainers = [ "DaRacci" ];
  };
}

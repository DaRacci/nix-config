{ writeShellApplication
, openssh
, lib
}: writeShellApplication {
  name = "create-proxmox-container";

  runtimeInputs = [ openssh ];

  excludeShellChecks = [ "SC1072" "SC2029" ];

  text = /*bash*/ ''
    # Set sane defaults
    ROOT_DISK_SIZE=8
    MEMORY=2048
    CPU_CORES=2
    NAME=""

    get_user_input() {
      local prompt=''${1:?Missing prompt argument.}
      local default=''${!2-}
      local nullable=''${3:-true}

      while true; do
        if [ -z "''${default}" ]; then
          read -rp "Enter ''${prompt}: " input
        else
          read -rp "Enter ''${prompt} (default: ''${default}): " input
        fi

        if [ -z "''${input}" ]; then
          if [ "''${nullable}" = false ]; then
            echo "Input cannot be empty."
            continue
          fi

          echo "''${default}"
          break
        else
          echo "''${input}"
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

    # Get the template name to use
    TEMPLATE_NAME=$(get_user_input "host flake name" null false)
    copy-to-proxmox "\''${NAME}"

    FEATURES="nesting=1"

    # shellcheck disable=SC2087
    ssh root@192.168.2.210 <<EOF
      # Get the next available ID
      ID=\$(pvesh get /cluster/nextid)
      # TZ=\$(cat /etc/timezone)

      # Verify that the template exists
      TEMPLATE=/var/lib/vz/template/cache/''${TEMPLATE_NAME}-x86_64-linux.tar.gz
      if [ ! -f "\''${TEMPLATE}" ]; then
        echo "Template not found at \''${TEMPLATE}. Exiting."
        exit 1
      fi

      # Create the container
      pct create "\''${ID}" "\''${TEMPLATE}" \
        --hostname "''${NAME}" --memory "''${MEMORY}" --cores "''${CPU_CORES}" \
        -net0 name=eth0,bridge=vmbr0,ip=dhcp,type=veth --storage local-zfs \
        -rootfs local-zfs:"''${ROOT_DISK_SIZE}" --mp0 local-zfs:16,mp=/nix/store \
        -unprivileged 1 --cmode console --arch amd64 --start 0 --onboot 1 \
        --features "''${FEATURES}"

      # Verify that the container was created successfully
      if [ \$? -eq 0 ]; then
        echo "Container created successfully!"
      else
        echo "Error creating container. Check the output for more information."
        exit 1
      fi

      # Start the container
      pct start "\''${ID}"

      # Verify that the container was started successfully
      if [ \$? -eq 0 ]; then
        echo "Container started successfully!"
      else
        echo "Error starting container. Check the output for more information."
        exit 1
      fi
    EOF
  '';

  meta = {
    description = "Create a new proxmox container from a template.";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = [ "DaRacci" ];
  };
}

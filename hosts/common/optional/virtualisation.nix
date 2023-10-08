{ pkgs, ... }:

let
  nur-no-pkgs = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") { };
  bridgeInterface = "br0";
  ethInterface = "eth0";
  cores = 24;
in
{
  imports = [
    # ../../modules/nixos
    # nur-no-pkgs.repos.crtified.modules.vfio
    nur-no-pkgs.repos.crtified.modules.virtualisation.nix
  ];

  virtualisation = {
    vfio = {
      enable = true;
      IOMMUType = "amd";
      devices = [ "10de:1b06" "10de:10ef" ];
    };

    sharedMemoryFiles = {
      looking-glass = {
        user = "racci";
        group = "qemu-libvirtd";
        mode = "666";
      };
    };

    libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";

      allowedBridges = [ "${bridgeInterface}" ];

      qemu = {
        runAsRoot = false;
        ovmf.enable = true;
      };

      # deviceACL = [
      #   "/dev/vfio/vfio"
      #   "/dev/kvm"
      #   "/dev/shm/looking-glass"
      # ];
    };
  };

  networking = {
    interfaces."${bridgeInterface}".useDHCP = true;
    bridges."${bridgeInterface}".interfaces = [ "${ethInterface}" ];
  };

  systemd = {
    services."libvirt-nosleep@" = {
      description = "Preventing sleep while libvirt domain \"%i\" is running";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=sleep --why=\"Libvirt domain \"%i\" is running\" --who=%U --mode=block sleep infinity";
      };
    };

    tmpfiles.rules =
      let
        per-machine = pkgs.writeShellApplication {
          name = "per-machine";

          runtimeInputs = [ ];

          text = ''
            #!${pkgs.stdenv.shell}

            GUEST_NAME="$1"
            HOOK_NAME="$2"
            STATE_NAME="$3"

            # Inhibit sleep
            case "$HOOK_NAME" in
              start)
                systemctl start "libvirt-nosleep@$GUEST_NAME" 2>&1 | tee -a /var/log/libvirt/hooks.log
                ;;
              stopped)
                systemctl stop "libvirt-nosleep@$GUEST_NAME" 2>&1 | tee -a /var/log/libvirt/hooks.log
                ;;
            esac

            BASEDIR="$(dirname "$0")"
            HOOKPATH="$BASEDIR/qemu.d/$GUEST_NAME/$HOOK_NAME/$STATE_NAME"

            set -e # If a script exits with an error, we should as well.

            # check if it's a non-empty executable file
            if [ -f "$HOOKPATH" ] && [ -s "$HOOKPATH" ] && [ -x "$HOOKPATH" ]; then
              "$HOOKPATH" "$@"
            elif [ -d "$HOOKPATH" ]; then
              while read -r file; do
                # check for null string
                if [ -n "$file" ]; then
                  "$file" "$@"
                fi
              done <<< "$(find -L "$HOOKPATH" -maxdepth 1 -type f -executable -print;)"
            fi
          '';
        };

        win-isolation-start = pkgs.writeShellApplication {
          name = "windows-isolation-start";

          # runtimeInputs = with pkgs; [ awk dmidecode ];

          text = ''
            #!${pkgs.stdenv.shell}

            # Numa node formula
            # CORES=$(dmidecode -t processor | grep "Core Count" | awk '{print $3}')
            # THREADS=$(dmidecode -t processor | grep "Thread Count" | awk '{print $3}')
            
            # ALLOWED="$($CORES / 2)-$($CORES - 1),$($THREADS - (($CORES / 2) - 1))-$(($THREADS - 1))"
            ALLOWED="${toString (cores / 4)}-${toString ((cores / 2) - 1)},${toString (cores - (cores / 4))}-${toString (cores - 1)}"

            systemctl set-property --runtime -- user.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- system.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- init.scope AllowedCPUs=$ALLOWED
          '';
        };

        win-isolation-release = pkgs.writeShellApplication {
          name = "windows-isolation-release";

          # runtimeInputs = [ ];

          text = ''
            #!${pkgs.stdenv.shell}

            ALLOWED="0-${toString (cores - 1)}"

            systemctl set-property --runtime -- user.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- system.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- init.scope AllowedCPUs=$ALLOWED
          '';
        };

        # detach-gpu = pkgs.writeText "detach-gpu" ''
        #   #!${pkgs.stdenv.shell}

        #   # Load variables we defined
        #   source "/var/lib/libvirt/hooks/kvm.conf"

        #   # Logout
        #   source "/home/owner/Desktop/Sync/Files/Tools/logout.sh"

        #   # Stop display manager
        #   systemctl stop display-manager.service

        #   # Unbind VTconsoles
        #   echo 0 > /sys/class/vtconsole/vtcon0/bind
        #   echo 0 > /sys/class/vtconsole/vtcon1/bind

        #   # Unbind EFI Framebuffer
        #   echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

        #   # Unload NVIDIA kernel modules
        #   modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia

        #   # Detach GPU devices from host
        #   virsh nodedev-detach $VIRSH_GPU_VIDEO
        #   virsh nodedev-detach $VIRSH_GPU_AUDIO

        #   # Load vfio module
        #   modprobe vfio-pci
        # '';

        # attach-gpu = pkgs.writeText "attach-gpu" ''
        #   #!${pkgs.stdenv.shell}

        #   # Load variables we defined
        #   source "/var/lib/libvirt/hooks/kvm.conf"

        #   # Unload vfio module
        #   modprobe -r vfio-pci

        #   # Attach GPU devices from host
        #   virsh nodedev-reattach $VIRSH_GPU_VIDEO
        #   virsh nodedev-reattach $VIRSH_GPU_AUDIO

        #   # Read nvidia x config
        #   nvidia-xconfig --query-gpu-info > /dev/null 2>&1

        #   # Load NVIDIA kernel modules
        #   modprobe nvidia_drm nvidia_modeset nvidia_uvm nvidia

        #   # Bind EFI Framebuffer
        #   echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind

        #   # Bind VTconsoles
        #   echo 1 > /sys/class/vtconsole/vtcon0/bind
        #   echo 1 > /sys/class/vtconsole/vtcon1/bind

        #   # Start display manager
        #   systemctl start display-manager.service
        # '';
      in
      [
        "L+ /run/libvirt/hooks/qemu - - - - ${pkgs.lib.getExe per-machine}"

        "L+ /run/libvirt/hooks/qemu.d/win11/start/begin/core-isolation - - - - ${pkgs.lib.getExe win-isolation-start}"
        "L+ /run/libvirt/hooks/qemu.d/win11/release/end/core-isolation - - - - ${pkgs.lib.getExe win-isolation-release}"

        "L+ /run/libvirt/hooks/qemu.d/win11-gaming/start/begin/core-isolation - - - - ${pkgs.lib.getExe win-isolation-start}"
        "L+ /run/libvirt/hooks/qemu.d/win11-gaming/release/end/core-isolation - - - - ${pkgs.lib.getExe win-isolation-release}"
      ];
  };

  environment = {
    sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
    systemPackages = (with pkgs; [
      virt-manager
      virtiofsd
      looking-glass-client
      win-virtio
      win-spice
      win-qemu
    ]);

    persistence."/persist" = {
      directories = [
        { directory = "/var/lib/libvirt/qemu"; user = "qemu-libvirtd"; group = "qemu-libvirtd"; mode = "u=rwx,g=rx,o=rx"; }
      ];
    };
  };
}

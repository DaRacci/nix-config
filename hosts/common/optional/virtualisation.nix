{ pkgs, ... }:

let
  nur-no-pkgs = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") { };
  bridgeInterface = "br0";
  ethInterface = "eth0";
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

  environment = {
    sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
    systemPackages =
      let
        per-machine = pkgs.writeText "/var/run/libvirt/hooks/qemu" ''
          #!/run/current-system/sw/bin/bash

          GUEST_NAME="$1"
          HOOK_NAME="$2"
          STATE_NAME="$3"
          MISC="''${@:4}"

          BASEDIR="$(dirname $0)"
          HOOKPATH="$BASEDIR/qemu.d/$GUEST_NAME/$HOOK_NAME/$STATE_NAME"

          set -e # If a script exits with an error, we should as well.

          # check if it's a non-empty executable file
          if [ -f "$HOOKPATH" ] && [ -s "$HOOKPATH"] && [ -x "$HOOKPATH" ]; then
            eval \"$HOOKPATH\" "$@"
          elif [ -d "$HOOKPATH" ]; then
            while read file; do
              # check for null string
              if [ ! -z "$file" ]; then
                eval \"$file\" "$@"
              fi
            done <<< "$(find -L "$HOOKPATH" -maxdepth 1 -type f -executable -print;)"
          fi
        '';

        # TODO: Don't hardcode the allowed cores
        core-isolation = pkgs.writeText "/var/run/libvirt/hooks/qemu.d/core-isolation" ''
          #!/run/current-system/sw/bin/bash

          HOOK_NAME="$2"
          STATE_NAME="$3"

          if [ "$HOOK_NAME" = "start" ] && [ "$STATE_NAME" = "begin" ]; then
            ALLOWED="6-11,18-23"
          elif [ "$STATE_NAME" = "release" ] && [ "$STATE_NAME" = "end" ]; then
            ALLOWED="0-23"
          fi

          systemctl set-property --runtime -- user.slice AllowedCPUs=$ALLOWED
          systemctl set-property --runtime -- system.slice AllowedCPUs=$ALLOWED
          systemctl set-property --runtime -- init.scope AllowedCPUs=$ALLOWED
        '';

        # detach-gpu = pkgs.writeText "/var/run/libvirt/hooks/qemu.d/detach-gpu" ''
        #   #!/run/current-system/sw/bin/bash

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

        # attach-gpu = pkgs.writeText "/var/run/libvirt/hooks/qemu.d/attach-gpu" ''
        #   #!/run/current-system/sw/bin/bash

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
      [ ] ++ (with pkgs; [
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

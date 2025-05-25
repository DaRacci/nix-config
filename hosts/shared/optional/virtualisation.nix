{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  nur-no-pkgs = import inputs.nur { };
  bridgeInterface = "br0";
  ethInterface = "eth0";
  cores = 24;
  GPU_VIDEO = "0b:00.0";
  GPU_AUDIO = "0b:00.1";
in
{
  imports = [
    nur-no-pkgs.repos.crtified.modules.virtualisation.nix
  ];

  boot = {
    extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
    extraModprobeConfig = ''
      options kvmfr static_size_mb=128
    '';
  };

  services.spice-autorandr.enable = true;

  virtualisation = {
    spiceUSBRedirection.enable = true;

    vfio = {
      enable = true;
      disableEFIfb = true;
      IOMMUType = "amd";
      devices = [
        "10de:1b06"
        "10de:10ef"
      ];
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
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [
            (pkgs.OVMFFull.override {
              secureBoot = true;
              tpmSupport = true;
              msVarsTemplate = true;
            }).fd
          ];
        };

        verbatimConfig = ''
          cgroup_device_acl = [
            "/dev/null", "/dev/full", "/dev/zero",
            "/dev/random", "/dev/urandom",
            "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
            "/dev/rtc","/dev/hpet", "/dev/vfio/vfio",
            "/dev/kvmfr0"
          ]
        '';
      };
    };
  };

  networking = {
    interfaces."${bridgeInterface}".useDHCP = true;
    bridges."${bridgeInterface}".interfaces = [ "${ethInterface}" ];
  };

  systemd = {
    services."libvirt-nosleep@" = {
      description = ''Preventing sleep while libvirt domain "%i" is running'';
      serviceConfig = {
        Type = "simple";
        ExecStart = ''${pkgs.systemd}/bin/systemd-inhibit --what=sleep --why="Libvirt domain "%i" is running" --who=%U --mode=block sleep infinity'';
      };
    };

    tmpfiles.rules =
      let
        per-machine = pkgs.writeShellApplication {
          name = "per-machine";

          runtimeInputs = with pkgs; [
            systemd
            findutils
          ];

          text = ''
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
            HOOKPATH="$BASEDIR/guests/$GUEST_NAME/$HOOK_NAME/$STATE_NAME"

            set -e # If a script exits with an error, we should as well.

            echo "Attempting to run $HOOKPATH" 2>&1 | tee -a /var/log/libvirt/hooks.log
            # check if it's a non-empty executable file
            if [ -f "$HOOKPATH" ] && [ -s "$HOOKPATH" ] && [ -x "$HOOKPATH" ]; then
              echo "Running $HOOKPATH" 2>&1 | tee -a /var/log/libvirt/hooks.log
              "$HOOKPATH" "$@" 2>&1 | tee -a /var/log/libvirt/hooks.log
            elif [ -d "$HOOKPATH" ]; then
              while read -r file; do
                # check for null string
                if [ -n "$file" ]; then
                  echo "Running $file" 2>&1 | tee -a /var/log/libvirt/hooks.log
                  "$file" "$@" 2>&1 | tee -a /var/log/libvirt/hooks.log
                fi
              done <<< "$(find -L "$HOOKPATH" -maxdepth 1 -type f -executable -print;)"
            fi
          '';
        };

        win-isolation-start = pkgs.writeShellApplication {
          name = "windows-isolation-start";

          runtimeInputs = with pkgs; [ systemd ];

          text = ''
            # Numa node formula
            # CORES=$(dmidecode -t processor | grep "Core Count" | awk '{print $3}')
            # THREADS=$(dmidecode -t processor | grep "Thread Count" | awk '{print $3}')

            ALLOWED="${toString (cores / 4)}-${toString ((cores / 2) - 1)},${toString (cores - (cores / 4))}-${toString (cores - 1)}"

            systemctl set-property --runtime -- user.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- system.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- init.scope AllowedCPUs=$ALLOWED
          '';
        };

        win-isolation-release = pkgs.writeShellApplication {
          name = "windows-isolation-release";

          runtimeInputs = with pkgs; [ systemd ];

          text = ''
            ALLOWED="0-${toString (cores - 1)}"

            systemctl set-property --runtime -- user.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- system.slice AllowedCPUs=$ALLOWED
            systemctl set-property --runtime -- init.scope AllowedCPUs=$ALLOWED
          '';
        };

        # TODO - Only if one gpu is present on machine
        # TODO - Save open applications and restore them on release
        detach-gpu = pkgs.writeShellApplication {
          name = "detach-gpu";
          runtimeInputs = with pkgs; [
            systemd
            pciutils
            gnugrep
            findutils
            kmod
          ];
          text = ''
            ################################# Variables #################################

            ## Adds current time to var for use in echo for a cleaner log and script ##
            DATE=$(date +"%m/%d/%Y %R:%S :")

            ################################# Helpers ###################################

            # Save service state into /tmp/vfio-store-services for later restore
            function stop-save-service {
              if systemctl is-active --quiet "$1"; then
                output="/tmp/vfio-store-''${2:-services}"

                # Create file if it doesn't exist
                if test ! -e "$output"; then
                  touch "$output"
                fi

                # Skip if already saved, otherwise append to file
                grep -qsF "$1" "$output" || echo "$1" >> "$output"

                echo "$DATE Stopping $1"
                systemctl stop "$1"

                while systemctl is-active --quiet "$1"; do
                  echo "$DATE Waiting for $1 to stop"
                  sleep 0.5
                done
              fi
            }

            ################################## Script ###################################

            echo "$DATE Beginning of Startup!"

            # Stops services that may be using the GPU
            function stop-services {
              stop-save-service "display-manager.service"
              systemctl isolate multi-user.target

              stop-save-service "openrgb.service"
            }

            ##############################################################################################################################
            ## Unbind VTconsoles if currently bound (adapted and modernised from https://www.kernel.org/doc/Documentation/fb/fbcon.txt) ##
            ##############################################################################################################################
            function unbind-vtconsoles {
              if test -e "/tmp/vfio-bound-consoles"; then
                rm -f /tmp/vfio-bound-consoles
              fi

              for (( i = 0; i < 16; i++)); do
                if test -x /sys/class/vtconsole/vtcon"$i"; then
                  if [ "$(grep -c "frame buffer" /sys/class/vtconsole/vtcon"$i"/name)" = 1 ]; then
                    echo 0 > /sys/class/vtconsole/vtcon"$i"/bind
                    echo "$DATE Unbinding Console $i"
                    echo "$i" >> /tmp/vfio-bound-consoles
                  fi
                fi
              done
            }

            function unload-gpu-drivers {
              while read -r file; do
                # check for null string
                if [ -n "$file" ]; then
                  rm -f "$file"
                fi
              done <<< "$(find -L /tmp/ -maxdepth 1 -type f -name 'vfio-is-*' -print;)"

              if lspci -nn | grep -e VGA | grep -s NVIDIA ; then
                echo "$DATE System has an NVIDIA GPU"
                echo "true" > /tmp/vfio-is-nvidia

                if ! (echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind); then
                  echo "$DATE Failed to unbind frame buffer"
                fi

                stop-save-service "nvidia-persistenced.service" "nvidia"
                sleep 1

                ## Unload NVIDIA GPU drivers ##
                modprobe -r nvidia_uvm
                modprobe -r nvidia_drm
                modprobe -r nvidia_modeset
                modprobe -r nvidia
                modprobe -r i2c_nvidia_gpu
                modprobe -r drm_kms_helper
                modprobe -r drm

                echo "$DATE NVIDIA GPU Drivers Unloaded"
              fi

              if lspci -nn | grep -e VGA | grep -s AMD ; then
                echo "$DATE System has an AMD GPU"
                echo "true" >/tmp/vfio-is-amd
                echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

                ## Unload AMD GPU drivers ##
                modprobe -r drm_kms_helper
                modprobe -r amdgpu
                modprobe -r radeon
                modprobe -r drm

                echo "$DATE AMD GPU Drivers Unloaded"
              fi
            }

            function load-vfio-drivers {
              modprobe vfio
              modprobe vfio_pci
              modprobe vfio_iommu_type1
            }

            stop-services
            sleep 1
            unbind-vtconsoles
            sleep 1
            unload-gpu-drivers
            load-vfio-drivers

            # Detach GPU devices from host
            # virsh nodedev-detach ${GPU_VIDEO}
            # virsh nodedev-detach ${GPU_AUDIO}

            echo "$DATE End of Startup!"
          '';
        };

        attach-gpu = pkgs.writeShellApplication {
          name = "attach-gpu";
          runtimeInputs = with pkgs; [
            systemd
            gnugrep
            findutils
            kmod
          ];
          text = ''
            ################################# Variables #################################

            ## Adds current time to var for use in echo for a cleaner log and script ##
            DATE=$(date +"%m/%d/%Y %R:%S :")

            ################################## Helpers ##################################

            function start-service-from-input {
              input="/tmp/vfio-store-$1"

              if test -e "$input"; then
                while read -r SERVICE; do
                  if command -v systemctl; then
                    ## Make sure the variable got collected ##
                    echo "$DATE Var has been collected from file: $SERVICE"

                    echo "$DATE Starting $SERVICE"
                    systemctl start "$SERVICE"
                  fi
                done < "$input"
              fi
            }

            ################################## Script ###################################

            echo "$DATE Beginning of Teardown!"

            function unload-vfio-drivers {
              modprobe -r vfio_pci
              modprobe -r vfio_iommu_type1
              modprobe -r vfio
            }

            function load-gpu-drivers {
              if test -e "/tmp/vfio-is-nvidia" && grep -q "true" "/tmp/vfio-is-nvidia"; then
                echo "$DATE Loading NVIDIA GPU Drivers"

                modprobe drm
                modprobe drm_kms_helper
                modprobe i2c_nvidia_gpu
                modprobe nvidia
                modprobe nvidia_modeset
                modprobe nvidia_drm
                modprobe nvidia_uvm

                start-service-from-input "nvidia"

                echo "$DATE NVIDIA GPU Drivers Loaded"
              fi

              if test -e "/tmp/vfio-is-amd" && grep -q "true" "/tmp/vfio-is-amd"; then
                echo "$DATE Loading AMD GPU Drivers"

                modprobe drm
                modprobe amdgpu
                modprobe radeon
                modprobe drm_kms_helper

                echo "$DATE AMD GPU Drivers Loaded"
              fi
            }

            function bind-vtconsoles {
              if test ! -e "/tmp/vfio-bound-consoles"; then
                echo "$DATE No consoles to rebind"
                return
              fi

              input="/tmp/vfio-bound-consoles"
              while read -r consoleNumber; do
                if test -x /sys/class/vtconsole/vtcon"$consoleNumber"; then
                  if [ "$(grep -c "frame buffer" "/sys/class/vtconsole/vtcon$consoleNumber/name")" = 1 ]; then
                    echo "$DATE Rebinding console $consoleNumber"
                    echo 1 > /sys/class/vtconsole/vtcon"$consoleNumber"/bind
                  fi
                fi
              done < "$input"
            }

            unload-vfio-drivers
            load-gpu-drivers
            start-service-from-input "services"
            bind-vtconsoles

            echo "$DATE End of Teardown!"
          '';
        };

        machines =
          let
            prefix = "L+ /var/lib/libvirt/hooks/guests/";
          in
          builtins.foldl' (existing: new: existing ++ new) [ ] (
            builtins.map
              (guest: [
                "${prefix}${guest}/prepare/begin/core-isolation - - - - ${pkgs.lib.getExe win-isolation-start}"
                "${prefix}${guest}/release/end/core-isolation - - - - ${pkgs.lib.getExe win-isolation-release}"

                "${prefix}${guest}-single/prepare/begin/core-isolation - - - - ${pkgs.lib.getExe win-isolation-start}"
                "${prefix}${guest}-single/release/end/core-isolation - - - - ${pkgs.lib.getExe win-isolation-release}"
                "${prefix}${guest}-single/prepare/begin/detach-gpu - - - - ${pkgs.lib.getExe detach-gpu}" # TODO - Only if one gpu is present on machine
                "${prefix}${guest}-single/release/end/attach-gpu - - - - ${pkgs.lib.getExe attach-gpu}" # TODO - Only if one gpu is present on machine
              ])
              [
                "win11"
                "win11-gaming"
              ]
          );

        qemuFirmware = pkgs.runCommandNoCC "qemu-firmware" { } ''
          mkdir -p $out/share/firmware

          cat <<EOF > $out/share/firmware/30-edk2-ovmf-x64-sb-enrolled.json
          {
            "description": "OVMF with SB+SMM, SB enabled, MS certs enrolled",
            "interface-types": ["uefi"],
            "mapping": {
              "device": "flash",
              "mode": "split",
              "executable": {
                "filename": "/run/libvirt/nix-ovmf/OVMF_CODE.ms.fd",
                "format": "raw"
              },
              "nvram-template": {
                "filename": "/run/libvirt/nix-ovmf/OVMF_VARS.ms.fd",
                "format": "raw"
              }
            },
            "targets": [
              {
                "architecture": "x86_64",
                "machines": ["pc-q35-*"]
              }
            ],
            "features": [
              "acpi-s3",
              "enrolled-keys",
              "requires-smm",
              "secure-boot",
              "verbose-dynamic"
            ],
            "tags": []
          }
          EOF

          cat <<EOF > $out/share/firmware/40-edk2-ovmf-x64-sb.json
          {
            "description": "OVMF with SB+SMM, SB enabled",
            "interface-types": ["uefi"],
            "mapping": {
              "device": "flash",
              "mode": "split",
              "executable": {
                "filename": "/run/libvirt/nix-ovmf/OVMF_CODE.fd",
                "format": "raw"
              },
              "nvram-template": {
                "filename": "/run/libvirt/nix-ovmf/OVMF_VARS.fd",
                "format": "raw"
              }
            },
            "targets": [
              {
                "architecture": "x86_64",
                "machines": ["pc-q35-*"]
              }
            ],
            "features": [
              "acpi-s3",
              "secure-boot",
              "requires-smm",
              "verbose-dynamic"
            ],
            "tags": []
          }
        '';
      in
      lib.mkBefore (
        [
          "L+ /var/lib/libvirt/hooks/qemu - - - - ${pkgs.lib.getExe per-machine}"
          "L+ /var/lib/qemu/firmware - - - - ${qemuFirmware}/share/firmware"
        ]
        ++ machines
      );
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", OWNER="racci", GROUP="kvm", MODE="0660"
  '';

  environment = {
    sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
    systemPackages = with pkgs; [
      virt-manager
      virtiofsd
      win-virtio
      win-spice
      virtio-win
    ];
  };
  host.persistence.directories =
    let
      commonArgs = {
        user = "qemu-libvirtd";
        group = "qemu-libvirtd";
        mode = "u=rwx,g=rx,o=rx";
      };
    in
    [
      (commonArgs // { directory = "/var/lib/libvirt/qemu"; })
      (commonArgs // { directory = "/var/lib/libvirt/images"; })
      {
        directory = "/var/lib/libvirt/swtpm";
        mode = "u=rwx,g=rx,o=rx";
      }
      {
        directory = "/var/lib/libvirt/secrets";
        mode = "u=rw,g=x,o=x";
      }
      {
        directory = "/var/lib/swtpm-localca";
        mode = "u=rwx,g=rw,o=";
      }
    ];
}

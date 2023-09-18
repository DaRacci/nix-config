{ lib, pkgs, config, ... }:
with lib; let
  cfg = config.virtual-machines.guests;

  guestOpts = { name, config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        example = "win10";
        description = "The name of the guest virtual machine.";
      };

      os = {
        type = mkOption {
          type = types.strMatching "^(linux|windows)$";
          default = "windows";
          description = "The type of operating system to install.";
        };

        version = mkOption {
          type = types.str;
          default = "11";
          description = "The version of the operating system to install.";
        };
      };

      cpu = {
        threads = mkOption {
          type = types.int;
          default = 1;
          apply = v: if v < 1 then throw "threads must be positive" else v;
          description = "The number of threads to allocate to the guest.";
        };
      };

      memory = {
        sharedMemory = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to use shared memory.";
        };

        reservedMemory = mkOption {
          type = types.int;
          default = 0;
          apply = v: if v < 0 || v > 100 then throw "reservedMemory must be the percent of memory which is reserved, between 0 and 100" else v;
          description = mkDoc "The percentage of maxMemory to reserve for the host.";
        };

        maxMemory = mkOption {
          type = types.int;
          default = 2048;
          apply = v: if v < 0 then throw "maxMemory must be positive" else v;
          description = "The maximum amount of memory that can be allocated to the guest.";
        };
      };

      storage = {
        # TODO  
      };

      network = {
        mac = mkOption {
          type = types.str;
          default = "52:54:00:12:34:56";
          description = "The MAC address of the guest.";
        };

        hostNic = mkOption {
          type = types.str;
          default = "br0";
          description = "The name of the host network interface to bridge to.";
        };
      };

      tpm = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the TPM passthrough.";
      };

      graphics = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable the graphics passthrough.";
        };

        method = mkOption {
          type = types.strMatching "^(pci|mdev|spice)$";
          default = "spice";
          description = "The method of graphics passthrough.";
        };
      };

      audio = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable the audio passthrough.";
      };
    };
  };
in
{
  options.virtual-machines = {
    enable = mkEnableOption "Virtual machines";

    guests = mkOption {
      default = { };
      type = with types; attrsOf (submodule guestOpts);
    };
  };

  config = mkIf (cfg.enable && cfg.guests != { })
    (mkMerge mapAttrs'
      (name: guest:
        let
          xml = pkgs.writeText "libvirt-guest-${guest.name}.xml" ''
            <domain type="kvm">
              <name>${guest.name}</name>
              <uuid>UUID</uuid>
          '' + optional (guest.os.type == "windows") ''
            <metadata>
              <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
                <libosinfo:os id="http://microsoft.com/win/${guest.os.version}"/>
              </libosinfo:libosinfo>
            </metadata>
            <os>
              <type arch="x86_64" machine="pc-q35-8.0">hvm</type>
              <loader readonly="yes" type="pflash">/usr/share/OVMF/OVMF_CODE.fd</loader>
            </os>
          '' + ''
            <cpu mode="host-passthrough">
              <topology sockets="1" dies="1" cores="${toString (guest.cpu.threads / 2)}" threads="2"/>
              <feature policy="require" name="topoext"/>
              <feature policy="disable" name="hypervisor"/>
            </cpu>
          '' + ''
            <memory unit="MiB">${toString guest.memory.maxMemory}</memory>
            <currentMemory unit="MiB">${toString (guest.memory.maxMemory / (guest.memory.reservedMemory / 100))}</currentMemory>
          '' + optional guest.memory.sharedMemory ''
            <memoryBacking>
              <source mode="shared"/>
            </memoryBacking>
          '' + ''
            <features>
              <acpi/>
              <apic/>
              <kvm>
                <hidden state="on"/>
              </kvm>
              <vmport state="off"/>
              <smm state="on"/>
            </features>
          '' + ''
            <devices>
              <panic model="isa"/>
              <memballoon model="none"/>
              <watchdog model="i6300esb" action="reset"/>
              <rng model="virtio">
                <backend model="random">/dev/urandom</backend>
              </rng>
              <input type="mouse" bus="virtio"/>
              <input type="keyboard" bus="virtio"/>
              <channel type="spicevmc">
                <target type="virtio" name="com.redhat.spice.0"/>
              </channel>
              <interface type="direct">
                <source dev="${guest.network.hostNic}" mode="bridge"/>
                <mac address="${guest.network.mac}"/>
                <model type="virtio"/>
              </interface>
          '' + optional guest.tpm ''
            <tpm model="tpm-tis">
              <backend type="passthrough"/>
            </tpm>
          '' + optional guest.audio ''
            <sound model="ich9"/>
            <audio id="1" type="ich9"/>
          '' + optional guest.graphics.enable
            (if guest.graphics.method == "spice" then ''
              <graphics type="spice" autoport="yes">
                <listen type="address"/>
              </graphics>
            '' else if guest.graphics.method == "mdev" then ''
              ?????
            '' else ''
              <graphics type="spice" port="-1" autoport="no">
                <listen type="address"/>
                <gl enable="no"/>
              </graphics>
              <video>
                <model type="vga" vram="16384" heads="1" primary="yes"/>
              </video>
              <shmem name="looking-glass">
                <model type="ivshmem-plain"/>
                <size unit="M">64</size>
              </shmem>
            '') + ''
              </devices>
            </domain>
          '';
        in
        { }
          cfg.guests);


    systemd.services = lib.mapAttrs'
  (name: guest: lib.nameValuePair "libvirtd-guest-${name}" {
  after = [ "libvirtd.service" ];
  requires = [ "libvirtd.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = "yes";
  };
  script =
    let
      xml = pkgs.writeText "libvirt-guest-${name}.xml"
        ''
          <domain type="kvm">
            <name>${name}</name>
            <uuid>UUID</uuid>
            <os>
              <type>hvm</type>
            </os>
            <memory unit="GiB">${guest.memory}</memory>
            <devices>
              <disk type="volume">
                <source volume="guest-${name}"/>
                <target dev="vda" bus="virtio"/>
              </disk>
              <graphics type="spice" autoport="yes"/>
              <input type="keyboard" bus="usb"/>
              <interface type="direct">
                <source dev="${hostNic}" mode="bridge"/>
                <mac address="${guest.mac}"/>
                <model type="virtio"/>
              </interface>
            </devices>
            <features>
              <acpi/>
            </features>
          </domain>
        '';
    in
    ''
      uuid="$(${pkgs.libvirt}/bin/virsh domuuid '${name}' || true)"
      ${pkgs.libvirt}/bin/virsh define <(sed "s/UUID/$uuid/" '${xml}')
      ${pkgs.libvirt}/bin/virsh start '${name}'
    '';
  preStop =
    ''
      ${pkgs.libvirt}/bin/virsh shutdown '${name}'
      let "timeout = $(date +%s) + 10"
      while [ "$(${pkgs.libvirt}/bin/virsh list --name | grep --count '^${name}$')" -gt 0 ]; do
        if [ "$(date +%s)" -ge "$timeout" ]; then
          # Meh, we warned it...
          ${pkgs.libvirt}/bin/virsh destroy '${name}'
        else
          # The machine is still running, let's give it some time to shut down
          sleep 0.5
        fi
      done
    '';
})
guests;
};
}

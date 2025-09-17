{
  osConfig ? null,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom.audio;
  updatedDevicesPath = "wireplumber/wireplumber.conf.d/50-update-devices.conf";
  disabledDevicesPath = "wireplumber/wireplumber.conf.d/51-disabled-devices.conf";
  disabledNodesPath = "wireplumber/wireplumber.conf.d/52-disabled-nodes.conf";

  getType = target: if (lib.hasPrefix "alsa_card" target) then "device" else "node";
in
{
  options.custom.audio = {
    enable = mkEnableOption "Enable Audio Module" // {
      default = osConfig != null && !osConfig.host.device.isHeadless;
    };

    disabledDevices = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        A list of ALSA device names or node names to disable.
        To find the names use the guide at https://wiki.archlinux.org/title/WirePlumber#Obtain_interface_name_for_rules_matching
      '';
    };

    updateDevices = mkOption {
      type = with types; attrsOf (attrsOf str);
      default = { };
      description = ''
        A list of ALSA device names or node names to update.
        To find the names use the guide at https://wiki.archlinux.org/title/WirePlumber#Obtain_interface_name_for_rules_matching

        For available properties see these pages:
        https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#properties
      '';
    };
  };

  config = mkIf cfg.enable {
    services.playerctld = {
      enable = true;
      package = pkgs.playerctl;
    };

    xdg.configFile =
      let
        disabledNodes = filter (name: getType name == "node") cfg.disabledDevices;
        disabledDevices = filter (name: getType name == "device") cfg.disabledDevices;
      in
      {
        "${updatedDevicesPath}" = mkIf ((length (builtins.attrValues cfg.updateDevices)) > 0) {
          text = ''
            monitor.alsa.rules = [
              ${lib.pipe cfg.updateDevices [
                (lib.mapAttrs (
                  name: props: ''
                    {
                      matches = [
                        {
                          ${getType name}.name = "${name}"
                        }
                      ]

                      actions = {
                        update-props = {
                          ${lib.pipe props [
                            (mapAttrsToList (name: value: "${name} = ${builtins.toJSON value}"))
                            (concatStringsSep "\n")
                          ]}
                        }
                      }
                    }
                  ''
                ))
                (concatStringsSep "\n")
              ]}
            ]
          '';
        };

        "${disabledNodesPath}" = mkIf ((length disabledNodes) > 0) {
          text = ''
            monitor.alsa.rules = [{
              matches = [
                ${lib.pipe disabledNodes [
                  (map (name: ''
                    {
                      node.name = "${name}"
                    }
                  ''))
                  (concatStringsSep "\n")
                ]}
              ]

              actions = {
                update-props = {
                  node.disabled = true
                }
              }
            }]
          '';
        };

        "${disabledDevicesPath}" = mkIf ((length disabledDevices) > 0) {
          text = ''
            monitor.alsa.rules = [{
              matches = [
                ${lib.pipe disabledDevices [
                  (map (name: ''
                    {
                      device.name = "${name}"
                    }
                  ''))
                  (concatStringsSep "\n")
                ]}
              ]

              actions = {
                update-props = {
                  device.disabled = true
                }
              }
            }]
          '';
        };
      };

    custom.uwsm.sliceAllocation.background = [ "playerctld" ];
  };
}

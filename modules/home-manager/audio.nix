{ osConfig, config, pkgs, lib, ... }: with lib; let
  cfg = config.custom.audio;
  updatedDevicesPath = "wireplumber/wireplumber.conf.d/50-update-devices.conf";
  disabledDevicesPath = "wireplumber/wireplumber.conf.d/51-disable-devices.conf";
in
{
  options.custom.audio = {
    enable = mkEnableOption "Enable Audio Module" // {
      default = !osConfig.host.device.isHeadless;
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
      type = with types; listOf (submodule {
        options = {
          node = mkOption {
            type = str;
            description = ''
              The node name to update.
              To find the name use the guide at https://wiki.archlinux.org/title/WirePlumber#Obtain_interface_name_for_rules_matching
            '';
          };

          props = mkOption {
            type = with types; listOf (submodule {
              options = {
                name = mkOption {
                  type = str;
                  description = ''
                    The property name to update.
                    To find the name use the guide at https://wiki.archlinux.org/title/WirePlumber#Obtain_interface_name_for_rules_matching
                  '';
                };

                value = mkOption {
                  type = str;
                  description = ''
                    The property value to set.
                  '';
                };
              };
            });
            default = [ ];
            description = ''
              A list of properties to update.
            '';
          };
        };
      });
      default = [ ];
      description = ''
        A list of ALSA device names or node names to update.
        To find the names use the guide at https://wiki.archlinux.org/title/WirePlumber#Obtain_interface_name_for_rules_matching
      '';
    };
  };

  config = mkIf cfg.enable {
    services.playerctld = {
      enable = true;
      package = pkgs.playerctl;
    };

    xdg.configFile.${disabledDevicesPath} = mkIf ((length cfg.disabledDevices) > 0) {
      text = ''
        monitor.alsa.rules = [{
          matches = [
            ${
              trivial.pipe cfg.disabledDevices [
                (map (device: ''
                  {
                    device.name = "${device}"
                  },
                ''
                ))
                (concatStringsSep "\n")
              ]
            }
          ]

          actions = {
            update-props = {
              device.disabled = true;
            }
          }
        }]
      '';
    };

    xdg.configFile.${updatedDevicesPath} = mkIf ((length cfg.updateDevices) > 0) {
      text = ''
        monitor.alsa.rules = [
          ${
            trivial.pipe cfg.updateDevices [
              (map (device: ''
                {
                  matches = [
                    {
                      device.name = "${device.node}"
                    }
                  ]

                  actions = {
                    update-props = {
                      ${
                        trivial.pipe device.props [
                          (map (prop: ''
                            "${prop.name}" = "${prop.value}"
                          ''
                          ))
                          (concatStringsSep "\n")
                        ]
                      }
                    }
                  }
                }
              ''
              ))
              (concatStringsSep "\n")
            ]
          }
        ]
      '';
    };
  };
}

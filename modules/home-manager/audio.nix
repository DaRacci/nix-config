{ osConfig, config, pkgs, lib, ... }: with lib; let
  cfg = config.custom.audio;
  disabledDevicesPath = "wireplumber/main.lua.d/51-disable-devices.lua";
in
{
  options.custom.audio = {
    enable = mkEnableOption "Enable Audio Module" // { default = osConfig.host.device.role != "server"; };

    # disableHDMISources = mkEnableOption
    disabledDevices = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "List of audio devices to disable";
    };
  };

  config = mkIf cfg.enable {
    services.playerctld = {
      enable = true;
      package = pkgs.playerctl;
    };

    xdg.configFile.${disabledDevicesPath} = {
      # onChange = "systemctl restart wireplumber.service";

      text = mkIf ((length cfg.disabledDevices) > 0) ''
        rule = {
          matches = {
            ${
              trivial.pipe cfg.disabledDevices [
                (map (device: ''
                  {
                    { "device.name", "equals", "${device}" },
                  },
                ''
                ))
                (concatStringsSep "\n")
              ]
            }
          },
          apply_properties = {
            ["device.disabled"] = true,
          },
        }

        table.insert(alsa_monitor.rules, rule)
      '';
    };
  };
}

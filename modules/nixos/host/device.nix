{ flake, config, lib, ... }: with lib; let
  cfg = config.host.device;
in
{
  options.host.device = {
    enable = mkEnableOption "device specification";

    role = mkOption {
      type = types.enum [ "desktop" "laptop" "server" ];
      default = throw "A role must be specified";
      description = "The role of the device";
    };

    purpose = mkOption {
      type = with types; listOf (enum [ "development" "gaming" "media" "office" "server" "virtualization" ]);
      default = [ ];
      description = "The purpose(s) of the device.";
    };
  };

  config = mkIf cfg.enable { };
}

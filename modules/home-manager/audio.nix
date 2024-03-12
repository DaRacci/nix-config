{ config, lib, ... }: with lib; let cfg = config.custom.audio; in {
  options.custom.audio = {
    enable = mkEnableOption "Enable Audio Module" // { default = true; };

    # disableHDMISources = mkEnableOption
  };

  config = mkIf cfg.enable {
    services.pipewire = {
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
}
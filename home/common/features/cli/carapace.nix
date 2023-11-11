{ config, pkgs, ... }: {
  # programs.carapace = {
  #   enable = true;
  #   package = pkgs.carapace;

  #   enableBashIntegration = config.programs.bash.enable;
  #   enableZshIntegration = config.programs.zsh.enable;
  #   enableFishIntegration = config.programs.fish.enable;
  #   enableNushellIntegration = config.programs.nushell.enable;
  # };

  home.packages = with pkgs.unstable; [ carapace ];

  programs.nushell = {
    # Note, the ${"$"} below is a work-around because xgettext otherwise
    # interpret it as a Bash i18n string.
    extraEnv = ''
      let carapace_cache = "${config.xdg.cacheHome}/carapace"
      if not ($carapace_cache | path exists) {
        mkdir $carapace_cache
      }
      ${pkgs.unstable.carapace}/bin/carapace _carapace nushell | str replace 'def --env' 'def' --all | save -f ${"$"}"($carapace_cache)/init.nu"
    '';
    extraConfig = ''
      source ${config.xdg.cacheHome}/carapace/init.nu
    '';
  };
}

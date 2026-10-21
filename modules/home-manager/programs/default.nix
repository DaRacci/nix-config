{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./list-ephemeral.nix
  ];

  options.programs = { };

  config = {
    home.packages = [
      pkgs.folder-diff
      pkgs.compressor
    ];

    home.shell = {
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableIonIntegration = config.programs.ion.enable;
      enableNushellIntegration = config.programs.nushell.enable;
      enableZshIntegration = config.programs.zsh.enable;
    };
  };
}

{
  osConfig ? null,
  config,
  pkgs,
  lib,
  ...
}:
let
  minimal = osConfig != null && osConfig.host.device.role == "server";
in
lib.mkIf (osConfig == null || osConfig.users.users.${config.home.username}.shell.pname == "fish") {
  programs.fish = {
    enable = true;
    generateCompletions = !minimal;
    package = if minimal then pkgs.fishMinimal else pkgs.fish;
  };

  user.persistence.files = [ ".local/share/fish/fish_history" ];
}

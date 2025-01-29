{ pkgs, ... }:
{
  home.packages = with pkgs; [ protonmail-bridge ];

  systemd.user.services.protonmail-bridge = {
    Unit = {
      Description = "Protonmail Bridge";
      After = [ "network.target" ];
    };

    Service = {
      Restart = "always";
      ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --no-window --noninteractive --log-level info";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # programs.thunderbird = {
  #   enable = true;
  #   package = pkgs.thunderbird;

  #   settings = { };

  #   # profiles.racci = {
  #   #   settings = { };
  #   # };
  # };

  user.persistence.directories = [
    ".thunderbird"
    ".local/share/protonmail"
    ".config/protonmail"
  ];
}

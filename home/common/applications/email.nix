{ pkgs, ... }: {
  home.packages = with pkgs; [ hydroxide protonmail-bridge thunderbird ];

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

  user.persistence.directories = [ ".local/share/protonmail" ];
}

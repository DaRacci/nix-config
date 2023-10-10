{ pkgs, persistenceDirectory, ... }: {
  home.packages = with pkgs; [ protonmail-bridge thunderbird ];

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

  home.persistence."${persistenceDirectory}".directories = [ ".local/share/protonmail" ];
}

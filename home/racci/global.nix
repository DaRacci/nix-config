{ inputs, config, pkgs, ... }: {
  imports = [
    ./features/cli
  ];

  stylix = {
    base16Scheme = "${inputs.tinted-theming}/base16/tokyo-night-dark.yaml";

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 32;
    };

    fonts = rec {
      emoji = {
        package = pkgs.openmoji-color;
        name = "OpenMoji Color";
      };

      monospace = {
        package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
        name = "JetBrainsMono Nerd Font";
      };

      sansSerif = {
        package = pkgs.fira;
        name = "Fira Sans";
      };
      serif = sansSerif;

      sizes = {
        applications = 14;
        desktop = 12;
        popups = 14;
        terminal = 18;
      };
    };
  };

  programs.vdirsyncer.enable = true;
  services.vdirsyncer = {
    enable = true;
    frequency = "minutely";
  };

  accounts = {
    email = { };

    calendar = {
      basePath = ".calendar";
      accounts.personal = {
        primary = true;
        primaryCollection = "Personal";

        remote = {
          type = "caldav";
          url = "https://nextcloud.racci.dev/remote.php/dav";

          userName = "Racci";
          passwordCommand =
            let
              getPassScript = pkgs.writeScriptBin "get-pass" ''
                ${pkgs.lib.getExe' pkgs.uutils-coreutils-noprefix "cat"} ${config.sops.secrets.NEXTCLOUD_APP_PASSWORD.path}
              '';
            in
            [ "${getPassScript.outPath}/bin/get-pass" ];
        };

        vdirsyncer = {
          enable = true;
          collections = [ "Personal" "Contact Birthdays" ];

          timeRange = {
            start = /*py*/ ''datetime.now() + timedelta(days=365 * 2)'';
            end = /*py*/ ''datetime.now() - timedelta(days=365 * 2)'';
          };
        };
      };
    };
  };

  sops.secrets = {
    NEXTCLOUD_APP_PASSWORD = { };
  };
}

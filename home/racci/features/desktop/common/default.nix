{ config, pkgs, ... }: {
  imports = [
    ./denaro.nix
    ./nextcloud.nix
    ./podman.nix
    ./secrets.nix
  ];

  xdg.mimeApps.enable = true;

  sops.secrets = {
    NEXTCLOUD_APP_PASSWORD = { };
  };

  services.vdirsyncer = {
    enable = true;
    frequency = "minutely";
  };

  programs.vdirsyncer.enable = true;

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
}

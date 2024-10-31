{ config, pkgs, lib, ... }: rec {
  imports = [
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

  accounts =
    let
      passwordCommand = lib.getExe (pkgs.writeShellScriptBin "get-pass" ''
        ${pkgs.lib.getExe' pkgs.uutils-coreutils-noprefix "cat"} ${config.sops.secrets.NEXTCLOUD_APP_PASSWORD.path}
      '');
      mkRemote = type: {
        inherit type;
        url = "https://nextcloud.racci.dev/";

        userName = "Racci";
        passwordCommand = [ passwordCommand ];
      };
    in
    {
      email = { };

      contact = {
        basePath = ".contacts";
        accounts.personal = {
          remote = mkRemote "carddav";

          vdirsyncer = {
            enable = true;
            collections = [ "contacts" "work" ];
          };

          local = {
            type = "singlefile";
          };
        };
      };

      calendar = {
        basePath = ".calendar";
        accounts.personal = {
          primary = true;
          primaryCollection = "Personal";
          remote = mkRemote "caldav";

          vdirsyncer = {
            enable = true;
            collections = [ "personal" "contact_birthdays" ];

            # timeRange = {
            #   start = /*py*/ ''datetime.now() + timedelta(days=365 * 2)'';
            #   end = /*py*/ ''datetime.now() - timedelta(days=365 * 2)'';
            # };
          };
        };
      };
    };

  user.persistence.directories = [
    accounts.contact.basePath
    accounts.calendar.basePath
  ];
}

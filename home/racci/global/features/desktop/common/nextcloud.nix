{ pkgs, config, ... }: {
  home.packages = with pkgs; [ nextcloud-client ];

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  home.persistence."/persist/home/racci".directories = [
    ".config/Nextcloud"
  ];
}
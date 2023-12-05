{ pkgs, ... }: {
  home.packages = with pkgs; [
    nextcloud-client # Required to be able to use the nextcloud client and not only as a background service
    libsForQt5.qt5.qtwayland # Required for the nextcloud client to work on wayland
  ];

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  user.persistence.directories = [
    ".config/Nextcloud"
  ];
}

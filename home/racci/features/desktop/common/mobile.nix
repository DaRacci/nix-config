_: {
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  user.persistence.directories = [ ".config/kdeconnect" ];
}

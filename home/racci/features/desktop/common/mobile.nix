_: {
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  user.persistence.directories = [ ".config/kdeconnect" ];
  custom.uwsm.sliceAllocation = {
    background = [ "kdeconnect" ];
    background-graphical = [ "kdeconnect-indicator" ];
  };
}

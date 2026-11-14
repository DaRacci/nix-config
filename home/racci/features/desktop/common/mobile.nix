_: {
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  user.files.persistence.directories = [ ".config/kdeconnect" ];
  core.uwsm.sliceAllocation = {
    background = [ "kdeconnect" ];
    background-graphical = [ "kdeconnect-indicator" ];
  };
}

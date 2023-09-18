{ pkgs, persistenceDirectory, ... }: {
  home.packages = with pkgs.unstable; [ grapejuice ];

  home.persistence.${persistenceDirectory}.directories = [
    ".config/brinkervii/grapejuice"
    ".local/share/grapejuice"
  ];
}

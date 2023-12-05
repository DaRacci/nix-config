{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [ grapejuice ];

  user.persistence.directories = [
    ".config/brinkervii/grapejuice"
    ".local/share/grapejuice"
  ];
}

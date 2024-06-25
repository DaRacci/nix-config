{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [
    vesktop
  ];

  user.persistence.directories = [
    ".config/vesktop"
  ];
}

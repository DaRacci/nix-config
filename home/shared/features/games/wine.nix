{ pkgs, ... }: {
  # TODO :: Auto run protonup-rs on rebuild so you don't have to manually run it every boot.
  home.packages = with pkgs; [
    bottles
  ];

  user.persistence.directories = [
    ".local/share/bottles"
  ];
}

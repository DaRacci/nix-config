{ inputs, pkgs, ... }: {
  imports = [
    inputs.ags.homeManagerModules.default
  ];

  home.packages = with inputs.astal.packages.${pkgs.system}; [
    default
    io
  ];

  programs.ags = {
    enable = true;
    # configDir = "${inputs.asztal}/ags";

    extraPackages = with pkgs; [
      fzf
      bun
      gtksourceview
      # webkitgtk
      accountsservice
      dart-sass
      gtk3
      gtk4
    ] ++ (with inputs.ags.packages.${pkgs.system}; [
      apps
      auth
      battery
      bluetooth
      hyprland
      mpris
      network
      notifd
      powerprofiles
      tray
      wireplumber
      inputs.astal.packages.${pkgs.system}.default
    ]);
  };
}

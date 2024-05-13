{ inputs, pkgs, ... }: {
  imports = [
    inputs.ags.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    inputs.asztal.packages.${pkgs.system}.default
    # bun
    # dart-sass
    # brightnessctl
    # swww
    # slurp
    # wf-recorder
    # inputs.asztal.inputs.matugen.packages.${system}.default
    wl-clipboard
    # wayshot
    # swappy
    # hyprpicker
    # gtk3
    # pavucontrol
    # networkmanager
  ];

  programs.ags = {
    enable = true;
    configDir = "${inputs.asztal}/ags";

    extraPackages = with pkgs; [
      accountsservice
    ];
  };
}

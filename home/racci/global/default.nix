{ inputs, lib, config, outputs, pkgs, ... }:

let
  colourScheme = inputs.nix-colours.colorSchemes.onedark;
in {
  imports = [
    #? TODO :: Globalise
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.nix-colours.homeManagerModules.default
    ./nix.nix
    ./features/cli
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # TODO :: Globalise?
  programs.home-manager.enable = true;
  programs.git.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home = {
    username = lib.mkDefault "racci";
    homeDirectory = lib.mkDefault "/home/racci";
    stateVersion = lib.mkDefault "23.05";
    sessionPath = [ "$HOME/.local/bin" ];

    persistence."/persist/home/racci" = {
      directories = [
        "Documents"
        "Downloads"
        "Media"
        ".local/share/keyrings"
      ];

      allowOther = true;
    };

    file.".colorscheme".text = colourScheme.slug;
  };

  colorscheme = lib.mkDefault colourScheme;
}

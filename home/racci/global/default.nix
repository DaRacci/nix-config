{ inputs, lib, config, outputs, ... }:

let
  inherit (inputs.nix-colours.colorSchemes) onedark;
in {
  imports = [
    #? TODO :: Globalise
    inputs.impermanence.nixosModules.home-manager.impermanence
    inputs.nix-colours.homeManagerModule
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;

    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
    };
  };

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home = {
    username = lib.mkDefault "racci";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "22.11";
    sessionPath = [ "$HOME/.local/bin" ];

    # persistence = {
    #   "/persist/${config.home.homeDirectory}" = {
    #     directories = [
    #       "Documents"
    #       "Downloads"
    #       "Media"
    #     ];

    #     allowOther = true;
    #   };
    # };

    file.".colorscheme".text = onedark.slug;
  };
}
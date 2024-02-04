{ system
, name
, pkgsFor
, ...
}:
let
  pkgs = pkgsFor system;
in (import ./mkDevShell.nix { inherit system name pkgsFor; }).overrideAttrs(oldAttrs: {
  nativeBuildInputs = with pkgs; [
    nix
    home-manager
    git

    # For Secure Boot Debugging
    sbctl

    # For sops-nix
    sops
    ssh-to-age
    age
  ] ++ oldAttrs.nativeBuildInputs;
})

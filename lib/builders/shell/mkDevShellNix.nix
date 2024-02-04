{ system
, name
, pkgsFor
, ...
}:
let
  baseShell = import ./mkDevShell.nix { inherit system name pkgsFor; };
  pkgs = pkgsFor system;
in
baseShell // {
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
  ] ++ baseShell.nativeBuildInputs;
}

{ pkgs
, lib

, name
, ...
}: (import ./mkDevShell.nix { inherit pkgs lib name; }).overrideAttrs (oldAttrs: {
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

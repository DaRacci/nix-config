{
  flake,
  inputs,
  osConfig ? null,
  config,
  pkgs,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.anyrun.homeManagerModules.anyrun
    inputs.nixput.homeManagerModules.nixput

    ./nix.nix
    ./sops.nix
    ./xdg.nix
  ] ++ builtins.attrValues (import "${flake}/modules/home-manager");

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home.activation.report-changes = config.lib.dag.entryAnywhere ''
    if [ ! -z "''${oldGenPath:-}" ]; then
      ${pkgs.nvd}/bin/nvd diff "$oldGenPath" "$newGenPath"
    fi
  '';

  dconf.enable =
    if (osConfig != null) then pkgs.lib.mkForce osConfig.programs.dconf.enable else false;

  home.stateVersion = "25.05";
}

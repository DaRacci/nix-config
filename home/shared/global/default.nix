{
  self,
  inputs,
  osConfig ? null,
  config,
  pkgs,
  ...
}:
let
  dconfEnabled =
    if (osConfig != null) then pkgs.lib.mkForce osConfig.programs.dconf.enable else false;
in
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    # inputs.nixput.homeManagerModules.nixput

    ./nix.nix
    ./sops.nix
    ./xdg.nix
  ]
  ++ builtins.attrValues (import "${self}/modules/home-manager");

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home = {
    preferXdgDirectories = true;
    activation.report-changes = config.lib.dag.entryAnywhere ''
      if [ ! -z "''${oldGenPath:-}" ]; then
        ${pkgs.nvd}/bin/nvd diff "$oldGenPath" "$newGenPath"
      fi
    '';
  };

  dconf.enable = dconfEnabled;
  user.persistence.directories = [ ".config/dconf" ];

  home.stateVersion = "25.05";
}

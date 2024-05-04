{ inputs, osConfig, config, pkgs, ... }: {
  imports = [
    inputs.nur.hmModules.nur
    inputs.sops-nix.homeManagerModule
    inputs.anyrun.homeManagerModules.default
  ] ++ [
    ./dynamic-linker.nix
    ./nix.nix
    ./sops.nix
    ./xdg.nix
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home.activation.report-changes = config.lib.dag.entryAnywhere ''
    if [ ! -z "$oldGenPath" ]; then
      ${pkgs.nvd}/bin/nvd diff "$oldGenPath" "$newGenPath"
    fi
  '';

  dconf.enable = pkgs.lib.mkForce osConfig.programs.dconf.enable;
}

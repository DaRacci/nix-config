# Just disable and reduce as much as possible, no sense in keeping stuff around that is not used.
{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/perlless.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];

  programs = {
    nano.enable = false;
    bash.enable = false;
  };

  services.fstrim.enable = false;

  system = {
    tools = {
      nixos-enter.enable = false;
      nixos-option.enable = false;
      nixos-version.enable = false;
      nixos-install.enable = false;
      nixos-build-vms.enable = false;
      nixos-generate-config.enable = false;
    };

    # Want the perlless profile but some machines still need perl.
    forbiddenDependenciesRegexes = lib.mkForce [ ];
  };

  environment = {
    defaultPackages = lib.mkDefault [ ];
    corePackages = lib.mkForce [ ];
  };

  fonts.fontconfig.enable = false;
}

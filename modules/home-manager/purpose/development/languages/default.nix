{
  lib,
  ...
}:
let
  inherit (lib) types mkOption;
  inherit (types) listOf package;
in
{
  imports = [
    ./csharp.nix
    ./jvm.nix
    ./nix.nix
    ./powershell.nix
    ./python.nix
    ./rust.nix
  ];

  options.purpose.development.languages = {
    commonPackages = mkOption {
      type = listOf package;
      default = [ ];
      description = ''
        Packages that will be installed to all IDEs/editors that support them.
        This is useful for things like language servers or formatters that are shared across multiple languages.

        Or just defaults that you want to have available in all your development environments, like nix-index or direnv.
      '';
    };
  };
}

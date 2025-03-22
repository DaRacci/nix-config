{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.purpose;
in
{
  imports = [
    ./jvm.nix
    ./nix.nix
    ./rust.nix
    ./editors
  ];

  options.purpose.development = {
    enable = mkEnableOption "development";

    python = {
      enable = mkEnableOption "Enable Python Development";
    };
  };

  config = mkIf cfg.development.enable {
    assertions = [
      {
        assertion = !cfg.enable;
        message = ''
          You have enabled development but not the purpose module itself, which is required.
          Ensure that `purpose.enable` is set to true.
        '';
      }
    ];

    home.packages = with pkgs; [
      sysprof
      textpieces
      letterpress
      delineate
      iplookup-gtk
      hashes
      wildcard
      devtoolbox
    ];

    user.persistence.directories = [
      "Projects"

      # JetBrains IDEs
      ".local/share/JetBrains"
      ".cache/JetBrains" # TODO :: use version from pkg to limit further
      ".config/JetBrains" # Needed?
    ];
  };
}

{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.purpose.development;
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

  config = mkIf cfg.enable {
    user.persistence.directories = [
      "Projects"

      # JetBrains IDEs
      ".local/share/JetBrains"
      ".cache/JetBrains" # TODO :: use version from pkg to limit further
      ".config/JetBrains" # Needed?
    ];
  };
}

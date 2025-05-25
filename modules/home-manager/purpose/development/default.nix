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

    dotnet = {
      enable = mkEnableOption "Enable .NET Development, this includes PowerShell";
    };
  };

  config = mkIf cfg.development.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = ''
          You have enabled development but not the purpose module itself, which is required.
          Ensure that `purpose.enable` is set to true.
        '';
      }
    ];

    home.packages = with pkgs; [
      act
      sysprof
      textpieces
      letterpress
      delineate
      iplookup-gtk
      hashes
      wildcard
      devtoolbox
    ];

    xdg.configFile."act/actrc".text = ''
      -P ubuntu-latest=catthehacker/ubuntu:act-latest
      -P ubuntu-24.04=catthehacker/ubuntu:act-24.04
      -P ubuntu-22.04=catthehacker/ubuntu:act-22.04
      -P ubuntu-20.04=catthehacker/ubuntu:act-20.04
      -P ubuntu-18.04=catthehacker/ubuntu:act-18.04
      --use-new-action-cache
      --action-offline-mode
      --pull false
      --artifact-server-path /tmp/artifacts
    '';

    user.persistence.directories = [
      "Projects"

      # JetBrains IDEs
      ".local/share/JetBrains"
      ".cache/JetBrains" # TODO :: use version from pkg to limit further
      ".config/JetBrains" # Needed?
    ];
  };
}

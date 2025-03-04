{
  osConfig ? null,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.user.persistence;
in
{
  options.user.persistence = {
    enable = mkEnableOption "persistence";

    root = mkOption {
      readOnly = osConfig != null;
      default =
        if (osConfig != null) then
          "${osConfig.host.persistence.root}/home/${config.home.username}"
        else
          "/persist/home/${config.home.username}";
    };

    directories = mkOption {
      type =
        with types;
        listOf (
          either str (submodule {
            options = {
              directory = mkOption {
                type = str;
                default = null;
                description = "The directory path to be linked.";
              };
            };
          })
        );
      default = [ ];
      example = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        "VirtualBox VMs"
        ".gnupg"
        ".ssh"
        ".local/share/keyrings"
        ".local/share/direnv"
      ];
      description = ''
        A list of directories in your home directory that
        you want to link to persistent storage. You may optionally
        specify the linking method each directory should use.
      '';
    };

    files = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [ ".screenrc" ];
      description = ''
        A list of files in your home directory you want to
        link to persistent storage.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = osConfig == null || osConfig.host.persistence.enable;
        message = ''
          The "persistence" option is enabled, but the host does not have
          persistence enabled. This is probably a mistake, user persistence cannot be
          enabled without host persistence.
        '';
      }
    ];

    user.persistence.directories = [
      "Documents"
      "Downloads"
      "Pictures"
      "Videos"
      "Music"
      "Templates"
      ".local/share/keyrings"
    ];
  };
}

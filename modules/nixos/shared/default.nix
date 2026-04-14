{
  users,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    nameValuePair
    types
    ;
  inherit (types) listOf str;

  cfg = config.custom;
in
{
  imports = [
    ./core
    ./services
  ];

  options.custom = {
    defaultGroups = mkOption {
      type = listOf str;
      default = [ ];
      description = "Additional Groups to add all users to by default.";
    };
  };

  config = (mkIf (cfg.defaultGroups != [ ])) {
    users.users =
      users
      |> map (
        user:
        nameValuePair user {
          extraGroups = cfg.defaultGroups;
        }
      )
      |> builtins.listToAttrs;
  };
}
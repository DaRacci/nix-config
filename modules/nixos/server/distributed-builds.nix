{
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkMerge
    mkOption
    attrValues
    ;
  inherit (types) str listOf;
  inherit (builtins) map elem elemAt;

  cfg = config.server.distributedBuilder;
  thisIsBuildServer = elem config.networking.hostName cfg.builders;
in
{
  options.server.distributedBuilder = {
    builderUser = mkOption {
      type = str;
      readOnly = true;
      default = "builder";
      description = ''
        The user to use when connecting to remote build daemons.
      '';
    };

    builders = mkOption {
      type = listOf str;
      default = [ ];
      description = ''
        A list of hostnames of remote build daemons to connect to for distributed builds.
      '';
    };
  };

  config = mkMerge [
    (mkIf thisIsBuildServer {
      nix.settings.trusted-users = [ cfg.builderUser ];

      users = {
        groups.${cfg.builderUser} = { };
        users.${cfg.builderUser} = {
          isSystemUser = true;
          group = cfg.builderUser;
          home = "/var/lib/${cfg.builderUser}";

          openssh.authorizedKeys.keyFiles =
            attrValues self.nixosConfigurations
            |> map (system: elemAt system.config.users.users.root.openssh.authorizedKeys.keyFiles 0);
        };
      };
    })

    (mkIf (!thisIsBuildServer) {
      nix = {
        distributedBuilds = true;
        settings.builders-use-substitutes = true;

        buildMachines =
          cfg.builders
          |> map (
            hostName:
            let
              osConfig = self.nixosConfigurations.${hostName}.config;
            in
            {
              inherit hostName;
              inherit (osConfig.nixpkgs.hostPlatform) system;

              protocol = "ssh-ng";
              sshUser = cfg.builderUser;
              sshKey = config.sops.secrets.SSH_PRIVATE_KEY.path;
              supportedFeatures = [
                "kvm"
                "big-parallel"
              ];
            }
          );
      };
    })
  ];
}

{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.huntress;

  defaultConfig = builtins.toJSON {
    api_url = "https://huntress.io/api/v1";
    eetee_url = "https://eetee.huntress.io/phone_home";
  };
in
{
  options.services.huntress = {
    enable = lib.mkEnableOption "Huntress service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.huntress;
      description = "The Huntress package to use.";
    };

    accountKeyFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        The account key for the Huntress agent.
      '';
    };
    organisationKeyFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        The organisation key for the Huntress agent.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      huntress-agent = {
        description = "Protects your computer by detecting the malicious footholds used by hackers.";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        preStart = ''
          if [ -z "$(<"$CREDENTIALS_DIRECTORY/accountkey")" ]; then
            echo "Huntress account key is not set!"
            exit 1
          fi

          if [ -z "$(<"$CREDENTIALS_DIRECTORY/organizationkey")" ]; then
            echo "Huntress organisation key is not set!"
            exit 1
          fi

          cfgDir=/etc/huntress
          mkdir -p $cfgDir
          configFile="$cfgDir/agent_config.yaml"
          if [ ! -f "$configFile" ]; then
            echo "Creating default Huntress config file at $configFile"
            echo "${defaultConfig}" > "$configFile"
          fi

          # Merge the existing config file with the account key & org key
          keysFile="$cfgDir/keys.yaml"
          cat > "$keysFile" <<EOF
          account_key: $(<"$CREDENTIALS_DIRECTORY/accountkey")
          organization_key: $(<"$CREDENTIALS_DIRECTORY/organizationkey")
          EOF

          ${lib.getExe pkgs.yaml-merge} "$configFile" "$cfgDir/keys.yaml" > "$cfgDir/agent_config.yaml.tmp"
          mv "$cfgDir/agent_config.yaml.tmp" "$configFile"
          rm -f "$keysFile"
        '';

        unitConfig = {
          StartLimitInterval = 5;
          StartLimitBurst = 10;
        };

        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe' cfg.package "huntress-agent";
          WorkingDirectory = "-/run/huntress";
          User = "root";
          Restart = "always";
          RestartSec = 5;

          LoadCredential = [
            "accountkey:${cfg.accountKeyFile}"
            "organizationkey:${cfg.organisationKeyFile}"
          ];
        };
      };
    };
  };
}

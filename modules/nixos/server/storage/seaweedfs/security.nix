{
  config,
  lib,
  hostDirectory,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mkIf
    recursiveUpdate
    toLower
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  sopsPh = config.sops.placeholder;

  sopsCertAndKeys = {
    owner = "seaweedfs";
    group = "seaweedfs";
    mode = "0640";
  };

  sopsTlsFile =
    name:
    sopsCertAndKeys
    // {
      sopsFile = "${hostDirectory}/seaweedfs-tls/${name}";
      format = "binary";
    };

  tlsSecrets =
    map (service: {
      "SEAWEEDFS/TLS/${service}_CRT" = sopsTlsFile "${service}_CRT";
      "SEAWEEDFS/TLS/${service}_KEY" = sopsTlsFile "${service}_KEY";
    }) swLib.grpcTLSServices
    |> lib.foldl' recursiveUpdate { };

  commonSecretToml = ''
    [cors.allowed_origins]
    values = "*"

    [access]
    ui = true

    [grpc]
    ca = "${config.sops.secrets."SEAWEEDFS/TLS/CA".path}"

    ${
      map (service: ''
        [grpc.${toLower service}]
        cert = "${config.sops.secrets."SEAWEEDFS/TLS/${service}_CRT".path}"
        key = "${config.sops.secrets."SEAWEEDFS/TLS/${service}_KEY".path}"
      '') swLib.grpcTLSServices
      |> concatStringsSep "\n"
    }
  '';
in
{
  config = mkIf swLib.isEnabled {
    # Access to sops certs.
    users.users.caddy.extraGroups = [ "seaweedfs" ];

    sops = {
      # Certificates chain from offline root through SeaweedFS intermediate
      # to each component leaf.
      # `CA` is trust bundle and each `_CRT` value is leaf + intermediate.
      secrets = {
        "SEAWEEDFS/JWT/MASTER" = { };
        "SEAWEEDFS/JWT/MASTER_READ" = { };
        "SEAWEEDFS/JWT/FILER" = { };
        "SEAWEEDFS/JWT/FILER_READ" = { };
        "SEAWEEDFS/TLS/CA" = sopsTlsFile "CA";
      }
      // tlsSecrets;

      templates = {
        "SEAWEEDFS/SECURITY/FILER" = sopsCertAndKeys // {
          content = commonSecretToml + ''
            [jwt.filer_signing]
            key = "${sopsPh."SEAWEEDFS/JWT/FILER"}"
            expires_after_seconds = 10

            [jwt.filer_signing.read]
            key = "${sopsPh."SEAWEEDFS/JWT/FILER_READ"}"
            expires_after_seconds.read = 10

            [filer.expose_directory_metadata]
            enabled = true
          '';
        };

        "SEAWEEDFS/SECURITY/MASTER" = sopsCertAndKeys // {
          content = commonSecretToml + ''
            [jwt.signing]
            key = "${sopsPh."SEAWEEDFS/JWT/MASTER"}"
            expires_after_seconds = 10

            [jwt.signing.read]
            key = "${sopsPh."SEAWEEDFS/JWT/MASTER_READ"}"
            expires_after_seconds.read = 10
          '';
        };
      };
    };
  };
}

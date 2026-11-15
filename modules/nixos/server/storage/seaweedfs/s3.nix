{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatMap
    concatMapStrings
    intersectLists
    listToAttrs
    mapAttrsToList
    mkIf
    optionals
    optionalAttrs
    removeAttrs
    toJSON
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  s3 = config.services.seaweedfs.filer.s3;
  identityNames = builtins.attrNames s3.identities;

  unknownPolicies = builtins.filter (policy: !(builtins.hasAttr policy s3.policies)) (
    concatMap (name: s3.identities.${name}.policies) identityNames
  );

  # The filer expands `${VAR}` references in credentials against its own environment.
  mkCredential = identity: {
    accessKey =
      if identity.accessKey != null then identity.accessKey else "\${${identity.accessKeyEnv}}";
    secretKey =
      if identity.secretKey != null then identity.secretKey else "\${${identity.secretKeyEnv}}";
  };

  renderedIdentities = mapAttrsToList (
    name: identity:
    {
      inherit name;
      credentials = [ (mkCredential identity) ];
      policy_names = identity.policies;
    }
    // optionalAttrs identity.disabled { disabled = true; }
  ) s3.identities;

  renderedPolicies = mapAttrsToList (name: document: {
    inherit name;
    content = toJSON document;
  }) s3.policies;

  # Entries in the freeform document are appended to the generated ones.
  # Duplicate names would silently shadow each other, so they are rejected instead.
  freeformIdentities = s3.config.identities or [ ];
  freeformPolicies = s3.config.policies or [ ];

  duplicateIdentityNames = intersectLists (map (entry: entry.name or "") renderedIdentities) (
    map (entry: entry.name or "") freeformIdentities
  );

  duplicatePolicyNames = intersectLists (map (entry: entry.name or "") renderedPolicies) (
    map (entry: entry.name or "") freeformPolicies
  );

  identities = renderedIdentities ++ freeformIdentities;
  policies = renderedPolicies ++ freeformPolicies;

  document =
    removeAttrs s3.config [
      "identities"
      "policies"
    ]
    // optionalAttrs (identities != [ ]) { inherit identities; }
    // optionalAttrs (policies != [ ]) { inherit policies; };

  renderedConfig = pkgs.writeText "seaweedfs-s3.json" (toJSON document);

  envRefs = concatMap (
    name:
    let
      identity = s3.identities.${name};
    in
    optionals (identity.accessKey == null) [
      {
        env = identity.accessKeyEnv;
        secret = identity.accessKeySecret;
      }
    ]
    ++ optionals (identity.secretKey == null) [
      {
        env = identity.secretKeyEnv;
        secret = identity.secretKeySecret;
      }
    ]
  ) identityNames;

  secretOptions = {
    owner = "seaweedfs";
    group = "seaweedfs";
    mode = "0400";
    restartUnits = [ "seaweedfs-filer.service" ];
  };

  hasEnvRefs = envRefs != [ ];
in
{
  config = mkIf (swLib.isEnabled && s3.enable) {
    assertions = [
      {
        assertion = unknownPolicies == [ ];
        message = "services.seaweedfs.filer.s3.identities reference unknown policies: ${lib.concatStringsSep ", " unknownPolicies}";
      }
      {
        assertion = duplicateIdentityNames == [ ];
        message = "S3 identity names are declared twice, once in `identities` and once in `config.identities`: ${lib.concatStringsSep ", " duplicateIdentityNames}";
      }
      {
        assertion = duplicatePolicyNames == [ ];
        message = "S3 policy names are declared twice, once in `policies` and once in `config.policies`: ${lib.concatStringsSep ", " duplicatePolicyNames}";
      }
    ];

    services.seaweedfs.filer.s3.configFile = mkIf (document != { }) renderedConfig;

    sops.secrets = listToAttrs (
      map (ref: {
        name = ref.secret;
        value = secretOptions;
      }) envRefs
    );

    sops.templates = mkIf hasEnvRefs {
      "S3/ENV" = {
        owner = "seaweedfs";
        group = "seaweedfs";
        mode = "0400";
        content = concatMapStrings (ref: "${ref.env}=${config.sops.placeholder.${ref.secret}}\n") envRefs;
      };
    };

    systemd.services.seaweedfs-filer.serviceConfig.EnvironmentFile = mkIf hasEnvRefs [
      config.sops.templates."S3/ENV".path
    ];
  };
}

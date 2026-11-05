{ lib }:
let
  inherit (builtins) attrNames;
  inherit (lib)
    head
    mapAttrs
    replaceStrings
    sort
    tail
    toUpper
    ;

  providers = import ../providers.nix;

  providerBaseUrls = mapAttrs (_: provider: provider.baseUrl) providers;
  providerNames = attrNames providers;

  serviceConfig = service: provider: providers.${provider}.services.${service} or { };

  providerName = service: provider: (serviceConfig service provider).name or provider;

  providerSettings = service: provider: (serviceConfig service provider).settings or { };

  mapEntry = service: entry: {
    provider = providerName service entry.provider;
    inherit (entry) model;
  };

  mapFallbacks = service: entries: map (mapEntry service) entries;

  apiKeyEnv =
    provider:
    providers.${provider}.apiKeyEnv or "${toUpper (replaceStrings [ "-" ] [ "_" ] provider)}_API_KEY";

  secretReference =
    service: provider:
    let
      secrets = providers.${provider}.secrets or { };
      generated = "${toUpper (replaceStrings [ "-" ] [ "_" ] provider)}_API_KEY";
    in
    secrets.${service} or (secrets.default or generated);

  resolveChain =
    entries:
    let
      ordered = sort (a: b: a.priority < b.priority) entries;
    in
    {
      primary = head ordered;
      fallbacks = map (entry: { inherit (entry) provider model; }) (tail ordered);
    };
in
{
  inherit
    providerBaseUrls
    providerNames
    providerName
    providerSettings
    mapEntry
    mapFallbacks
    apiKeyEnv
    secretReference
    resolveChain
    ;
}

{ lib, languages }:
let
  inherit (lib)
    attrValues
    concatLists
    filter
    foldl'
    recursiveUpdate
    unique
    ;

  helpers = import ../../languages/lib.nix { inherit lib; };

  enabledLanguages = attrValues (helpers.enabled languages);

  vscodeConfig = language: language.editors.vscode or { };

  profileOf = language: (vscodeConfig language).profile or "default";

  forProfile = profile: filter (language: profileOf language == profile) enabledLanguages;

  extensions =
    profile:
    unique (
      concatLists (map (language: (vscodeConfig language).extensions or [ ]) (forProfile profile))
    );

  settings =
    profile:
    foldl' recursiveUpdate { } (
      map (language: (vscodeConfig language).settings or { }) (forProfile profile)
    );
in
{
  inherit extensions settings;
}

{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      failed = builtins.filter (assertion: !assertion.assertion) (self.validate lib self.data);
      manifest = import ./profile-sync-manifest.nix { inherit lib; };
    in
    {
      checks.data-consistency = pkgs.runCommand "data-consistency" { } (
        if failed == [ ] then
          "touch $out"
        else
          ''
            echo "data validation failed:" >&2
            ${lib.concatLines (map (assertion: "echo ${lib.escapeShellArg assertion.message} >&2") failed)}
            exit 1
          ''
      );

      checks.profile-sync-manifest = pkgs.runCommand "profile-sync-manifest" { } (
        if manifest.problems == [ ] then
          "touch $out"
        else
          ''
            echo "the compiled profile-sync manifest lost a declared policy field:" >&2
            ${lib.concatLines (map (problem: "echo ${lib.escapeShellArg problem} >&2") manifest.problems)}
            exit 1
          ''
      );
    };
}

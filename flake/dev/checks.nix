{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      failed = builtins.filter (assertion: !assertion.assertion) (self.validate lib self.data);
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
    };
}

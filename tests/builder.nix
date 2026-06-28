# VM Test Builder
#
# Auto-discovered: wraps host via mkNode.nix, injects vm-test profile, runs baseline.
# Explicit: scenario-defined nodes, baseline on all + scenario testScript.
{
  self,
  pkgs,
  lib,
  hostName ? null,
  allocations ? null,
  scenario ? null,
}:
assert (hostName != null) != (scenario != null);
let
  inherit (lib)
    nameValuePair
    listToAttrs
    ;
  inherit (builtins)
    mapAttrsToList
    attrNames
    concatStringsSep
    ;

  vmTestProfile = import ./profiles/vm-test.nix;

  baselineAssertions = nodeName: ''
    ${nodeName}.wait_for_unit("multi-user.target")
    ${nodeName}.wait_for_unit("sshd.service")
    ${nodeName}.succeed("journalctl --no-pager -n 1")
    out = ${nodeName}.succeed("systemctl list-units --state=failed --no-legend --no-pager")
    assert out.strip() == "", f"Failed units found on ${nodeName}: {out}"
  '';
in
if hostName != null then
  let
    hostNodeModule = import ./mkNode.nix {
      inherit self allocations hostName;
    };
  in
  pkgs.testers.runNixOSTest {
    name = hostName;

    nodes.${hostName} =
      { ... }:
      {
        imports = [
          hostNodeModule
          vmTestProfile
        ];
      };

    testScript = ''
      start_all()

      with subtest("${hostName} baseline"):
        ${baselineAssertions hostName}
    '';
  }
else
  pkgs.testers.runNixOSTest {
    name = scenario.name;

    nodes =
      scenario.nodes
      |> mapAttrsToList (
        nodeName: nodeModule:
        nameValuePair nodeName (
          { ... }:
          {
            imports = [
              nodeModule
              vmTestProfile
            ];
          }
        )
      )
      |> listToAttrs;

    testScript = ''
      start_all()

      ${concatStringsSep "\n" (
        map (nodeName: ''
          with subtest("${nodeName} baseline"):
            ${baselineAssertions nodeName}
        '') (attrNames scenario.nodes)
      )}

      ${scenario.testScript}
    '';
  }

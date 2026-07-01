# VM Test Builder
#
# Auto-discovered: wraps host via mkNode.nix, injects vm-test profile, runs baseline.
# Explicit: scenario-defined nodes, baseline on all + scenario testScript.
{
  self,
  inputs,
  pkgs,
  lib,
  hostName ? null,
  allocations ? null,
  scenario ? null,
  testUnits ? { },
  testFilter ? null,
}:
assert (hostName != null) != (scenario != null);
let
  inherit (lib)
    mapAttrsToList
    nameValuePair
    listToAttrs
    ;
  inherit (builtins)
    attrNames
    concatStringsSep
    elem
    isFunction
    ;

  filteredTestUnits =
    if testFilter == null then testUnits else lib.filterAttrs (name: _: elem name testFilter) testUnits;

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

    node.specialArgs = {
      inherit self inputs;
      inherit (self) outputs;
      hostDirectory = "${self}/hosts/server/${hostName}";
      users = [ ];
      importExternals = true;
    };

    nodes.${hostName} =
      { ... }:
      {
        imports = [
          hostNodeModule
          vmTestProfile
          inputs.disko.nixosModules.disko
        ];
      };

    testScript =
      { nodes, ... }:
      let
        nodeCfg = nodes.${hostName}.config;
        formatUnit =
          name: unit:
          let
            script = if isFunction unit.testScript then unit.testScript nodeCfg else unit.testScript;
          in
          ''
            with subtest("${hostName} ${name}"):
                ${script}'';
      in
      ''
        start_all()

        with subtest("${hostName} baseline"):
          ${baselineAssertions hostName}

        ${concatStringsSep "
" (mapAttrsToList formatUnit filteredTestUnits)}
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

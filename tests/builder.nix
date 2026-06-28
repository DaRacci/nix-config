# VM Test Builder
# Accepts either a hostname (auto-discovered mode) or a scenario attrset (explicit mode).
# Returns a NixOS VM test derivation built with pkgs.testers.runNixOSTest.
#
# Auto-discovered mode:
#   builder { inherit self pkgs lib inputs allocations hostName; }
#   - Wraps the host's full NixOS config (via mkNode.nix pattern)
#   - Injects tests/profiles/vm-test.nix
#   - Runs baseline assertions (boot, SSH, journald, failed units)
#
# Explicit scenario mode:
#   builder { inherit self pkgs lib inputs; scenario = { name, nodes, testScript, ... }; }
#   - Uses scenario-defined nodes (each injected with vm-test.nix)
#   - Runs baseline assertions on all nodes, then scenario-specific testScript
{
  self,
  pkgs,
  lib,
  inputs,
  # Auto-discovered mode args
  hostName ? null,
  allocations ? null,
  # Explicit scenario mode args
  scenario ? null,
}:
assert (hostName != null) != (scenario != null); # Exactly one mode must be specified
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

  # VM test profile module — injected into every test node
  vmTestProfile = import ./profiles/vm-test.nix;

  # Baseline testScript assertions applied to every node
  baselineAssertions = nodeName: ''
    # Verify boot completed
    ${nodeName}.wait_for_unit("multi-user.target")

    # Verify SSH is running
    ${nodeName}.wait_for_unit("sshd.service")

    # Verify journald is persisting logs
    ${nodeName}.succeed("journalctl --no-pager -n 1")

    # Verify no unexpected failed units
    out = ${nodeName}.succeed("systemctl list-units --state=failed --no-legend --no-pager")
    assert out.strip() == "", f"Failed units found on ${nodeName}: {out}"
  '';
in
if hostName != null then
  # --- Auto-discovered mode: single host VM test ---
  let
    # Build the host's NixOS config using the same mkNode pattern as the cluster test
    hostNodeModule = import ./mkNode.nix {
      inherit self allocations hostName;
    };
  in
  pkgs.testers.runNixOSTest {
    name = hostName;

    nodes.${hostName} = { ... }: {
      imports = [
        hostNodeModule
        vmTestProfile
      ];
    };

    extraSpecialArgs = { inherit inputs; };

    testScript = ''
      start_all()

      with subtest("${hostName} baseline"):
        ${baselineAssertions hostName}
    '';
  }
else
  # --- Explicit scenario mode ---
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

    extraSpecialArgs = { inherit inputs; };

    testScript = ''
      start_all()

      # Run baseline assertions on every node first
      ${concatStringsSep "\n" (
        map (nodeName: ''
          with subtest("${nodeName} baseline"):
            ${baselineAssertions nodeName}
        '') (attrNames scenario.nodes)
      )}

      # Run scenario-specific testScript
      ${scenario.testScript}
    '';
  }

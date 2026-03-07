{
  clusterHosts,
  allocations,

  self,
  pkgs,
  lib,
}:
let
  inherit (lib) nameValuePair listToAttrs;

  testLib = import ./lib.nix;
in
pkgs.testers.runNixOSTest {
  name = "cluster";

  nodes = clusterHosts |> map (hostName: nameValuePair hostName (import ./mkNode.nix {
    inherit self allocations hostName;
  })) |> listToAttrs;

  testScript = ''
    start_all()

    # Wait for all nodes to each multi-user.target
    with subtest("wait for multi-user.target on all nodes"):
      for node in cluster.nodes:
        with subtest(node.name):
          node.wait_for_unit("multi-user.target")
  '';
}

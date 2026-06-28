# Redis Remote Connect Scenario
# Verifies non-IO hosts can reach nixio redis and run PING/SET/GET.
#
# This scenario demonstrates how to write explicit multi-node VM tests.
# See docs/src/development/vm_integration_tests.md for guidance.
{
  nodes = {
    nixio = _: {
      services.redis.servers.remote = {
        enable = true;
        port = 6379;
        bind = "0.0.0.0";
        requirePass = null;
      };
      networking.firewall.allowedTCPPorts = [ 6379 ];
    };

    nixdev = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.redis ];
    };
  };

  testScript = ''
    start_all()

    with subtest("nixio redis accepts local connections"):
      nixio.wait_for_unit("redis-remote.service")
      nixio.wait_for_open_port(6379)
      nixio.succeed("redis-cli PING")

    with subtest("nixdev connects to remote redis on nixio"):
      nixdev.wait_for_unit("multi-user.target")
      nixdev.succeed("redis-cli -h nixio PING")
      nixdev.succeed("redis-cli -h nixio SET test_key hello")
      nixdev.succeed("redis-cli -h nixio GET test_key")
  '';
}

# Postgres Remote Connect Scenario
# Verifies non-IO hosts can connect to nixio postgres and run queries.
{
  nodes = {
    nixio = _: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "testdb" ];
        ensureUsers = [
          { name = "testuser"; }
        ];
        authentication = ''
          local all all trust
          host all all all trust
        '';
        enableTCPIP = true;
      };
      networking.firewall.allowedTCPPorts = [ 5432 ];
    };

    nixdev = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.postgresql ];
    };
  };

  testScript = ''
    start_all()

    with subtest("nixio postgres accepts local connections"):
      nixio.wait_for_unit("postgresql.service")
      nixio.wait_for_open_port(5432)
      nixio.succeed("sudo -u postgres psql -c 'SELECT 1'")

    with subtest("nixdev connects to remote postgres on nixio"):
      nixdev.wait_for_unit("multi-user.target")
      nixdev.succeed("psql -h nixio -U testuser -d testdb -c 'SELECT 1'")
  '';
}

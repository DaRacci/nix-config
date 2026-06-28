# Postgres Backup Scenario
# Verifies that a PostgreSQL database starts, accepts connections,
# and can receive a pg_dump from a client node.
#
# This scenario demonstrates how to write explicit multi-node VM tests.
# See docs/src/development/vm_integration_tests.md for guidance.
{
  nodes = {
    pg_server = _: {
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

    pg_client = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.postgresql ];
    };
  };

  testScript = ''
    with subtest("postgres accepts connections"):
      pg_client.wait_for_unit("multi-user.target")
      pg_client.succeed(
          "psql -h pg_server -U testuser -d testdb -c 'SELECT 1'"
      )

    with subtest("pg_dump completes without errors"):
      pg_client.succeed(
          "pg_dump -h pg_server -U testuser testdb > /tmp/dump.sql"
      )
      pg_client.succeed("test -s /tmp/dump.sql")
  '';
}

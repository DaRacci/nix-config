# Postgres Backup Scenario
# Verifies that a PostgreSQL database starts, accepts connections,
# and can receive a pg_dump from a client node.
#
# This scenario demonstrates how to write explicit multi-node VM tests.
# See docs/src/development/vm_integration_tests.md for guidance.
{
  nodes = {
    postgres-server = _: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "testdb" ];
        ensureUsers = [
          {
            name = "testuser";
            ensureDBOwnership = true;
            ensurePermissions = {
              "DATABASE testdb" = "ALL PRIVILEGES";
            };
          }
        ];
        authentication = ''
          local all all trust
          host all all all trust
        '';
        settings = {
          listen_addresses = "'*'";
        };
      };
      networking.firewall.allowedTCPPorts = [ 5432 ];
    };

    postgres-client = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.postgresql ];
    };
  };

  testScript = ''
    with subtest("postgres accepts connections"):
      postgres-client.wait_for_unit("multi-user.target")
      postgres-client.succeed(
          "psql -h postgres-server -U testuser -d testdb -c 'SELECT 1'"
      )

    with subtest("pg_dump completes without errors"):
      postgres-client.succeed(
          "pg_dump -h postgres-server -U testuser testdb > /tmp/dump.sql"
      )
      postgres-client.succeed("test -s /tmp/dump.sql")
  '';
}

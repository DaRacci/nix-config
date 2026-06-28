# IO Guardian Scenario
# Verifies cross-host database connectivity that io-guardian manages.
# nixio = coordinator host, nixdev = guardian client host.
# In production, io-guardian uses WebSocket PSK auth; this test validates
# the underlying DB connectivity pattern without real sops keys.
{
  nodes = {
    nixio = _: {
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        authentication = ''
          local all all trust
          host all all all trust
        '';
        ensureDatabases = [ "guardian_test" ];
        ensureUsers = [
          { name = "testuser"; }
        ];
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

    with subtest("nixio postgres accepts remote connection from nixdev"):
      nixdev.wait_for_unit("multi-user.target")
      nixdev.succeed(
          "psql -h nixio -U testuser -d guardian_test -c 'SELECT current_database()'"
      )

    with subtest("nixdev can create and query data on nixio via guardian-managed DB"):
      nixdev.succeed(
          "psql -h nixio -U testuser -d guardian_test "
          + "-c 'CREATE TABLE IF NOT EXISTS test_data "
          + "(id SERIAL PRIMARY KEY, val TEXT)'"
      )
      nixdev.succeed(
          "psql -h nixio -U testuser -d guardian_test "
          + "-c \"INSERT INTO test_data (val) VALUES ('guardian-test')\""
      )
      out = nixdev.succeed(
          "psql -h nixio -U testuser -d guardian_test -t -A "
          + "-c \"SELECT val FROM test_data WHERE id=1\""
      )
      assert out.strip() == "guardian-test", (
          f"Expected guardian-test, got '{out.strip()}'"
      )
  '';
}

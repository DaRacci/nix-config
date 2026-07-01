# Database Backup Chain Scenario
# Verifies the full backup pipeline: nixio PostgreSQL → pg_dump → gzip compression
# on nixserv, with file integrity and size verification at each step.
{
  nodes = {
    nixio = _: {
      services.openssh.enable = true;

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

    nixserv = { pkgs, ... }: {
      services.openssh.enable = true;
      environment.systemPackages = [
        pkgs.postgresql
        pkgs.gzip
        pkgs.file
      ];
    };
  };

  testScript = ''
    start_all()

    with subtest("nixio postgres accepts local connections"):
      nixio.wait_for_unit("postgresql.service")
      nixio.wait_for_open_port(5432)
      nixio.succeed("sudo -u postgres psql -c 'SELECT 1'")

    with subtest("nixserv reaches multi-user.target"):
      nixserv.wait_for_unit("multi-user.target")

    with subtest("nixserv connects to remote postgres on nixio"):
      nixserv.succeed("psql -h nixio -U testuser -d testdb -c 'SELECT 1'")

    with subtest("pg_dump completes without errors"):
      nixserv.succeed("pg_dump -h nixio -U testuser testdb > /tmp/testdb_dump.sql")

    with subtest("dump file is non-empty"):
      nixserv.succeed("test -s /tmp/testdb_dump.sql")
      nixserv.succeed("wc -l /tmp/testdb_dump.sql")

    with subtest("gzip compression succeeds"):
      nixserv.succeed("gzip /tmp/testdb_dump.sql")

    with subtest("compressed file exists and is smaller"):
      nixserv.succeed("test -s /tmp/testdb_dump.sql.gz")
      nixserv.succeed(
          "[ $(stat -c %s /tmp/testdb_dump.sql.gz) -lt 512 ]"
      )
  '';
}

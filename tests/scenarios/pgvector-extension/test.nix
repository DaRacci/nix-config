# pgvector-extension Scenario
# Verifies pgvector extension is available on nixio and accessible from nixcloud.
{
  nodes = {
    nixio = { pkgs, ... }: {
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        extraPlugins = [ pkgs.postgresqlPackages.pgvector ];
        authentication = ''
          local all all trust
          host all all all trust
        '';
        ensureDatabases = [ "vectordb" ];
        ensureUsers = [
          { name = "testuser"; }
        ];
      };
      networking.firewall.allowedTCPPorts = [ 5432 ];
    };

    nixcloud = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.postgresql ];
    };
  };

  testScript = ''
    start_all()
    nixio.wait_for_unit("postgresql.service")
    nixcloud.wait_for_unit("multi-user.target")

    with subtest("pgvector extension is installed on nixio"):
      nixio.succeed(
          "psql -U postgres -d vectordb -c 'CREATE EXTENSION IF NOT EXISTS vector;'"
      )

    with subtest("pgvector extension can be used on nixio"):
      nixio.succeed(
          "psql -U postgres -d vectordb -c 'CREATE TABLE IF NOT EXISTS embeddings (id SERIAL PRIMARY KEY, vec vector(3));'"
      )
      nixio.succeed(
          "psql -U postgres -d vectordb -c 'GRANT ALL ON embeddings TO testuser'"
      )
      nixio.succeed(
          "psql -U postgres -d vectordb -c 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO testuser'"
      )

    with subtest("testuser can insert and query embeddings"):
      nixio.succeed(
          "psql -U testuser -d vectordb -c \"INSERT INTO embeddings (vec) VALUES ('[1,2,3]'), ('[4,5,6]');\""
      )
      out = nixio.succeed(
          "psql -U testuser -d vectordb -c 'SELECT COUNT(*) FROM embeddings;'"
      )
      assert "2" in out, f"expected 2 rows, got: {out}"

    with subtest("nixcloud can connect to nixio and use pgvector"):
      nixcloud.succeed(
          "psql -h nixio -U testuser -d vectordb -c 'SELECT * FROM embeddings;'"
      )
  '';
}

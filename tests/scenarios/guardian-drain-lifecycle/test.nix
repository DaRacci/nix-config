# Guardian Drain Lifecycle Scenario
# Verifies the full guardian drain/undrain lifecycle:
# 1. PostgreSQL starts on nixio → coordinator sends undrain to nixdev → services start
# 2. Stop PostgreSQL → coordinator sends drain → services stop
# 3. Restart PostgreSQL → undrain runs again → services restart
{
  nodes = {
    nixio = { ... }: {
      imports = [ ./default.nix ];
      guardianDrainTest = {
        enable = true;
        role = "io-primary";
        guardianHost = "nixdev";
      };
    };

    nixdev = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.postgresql ];
      imports = [ ./default.nix ];
      guardianDrainTest = {
        enable = true;
        role = "guardian";
        ioPrimaryHost = "nixio";
      };
    };
  };

  testScript = ''
    start_all()

    with subtest("nixio PostgreSQL becomes ready"):
      nixio.wait_for_unit("postgresql.service")
      nixio.wait_for_open_port(5432)
      nixio.succeed("sudo -u postgres psql -c 'SELECT 1'")

    with subtest("nixio coordinator sends undrain to nixdev"):
      nixio.wait_for_unit("io-database-coordinator.service")
      out = nixio.succeed("systemctl show -p ActiveState io-database-coordinator.service")
      assert "active" in out, f"coordinator not active: {out}"

    with subtest("nixdev io-guardian server is running"):
      nixdev.wait_for_unit("io-guardian.service")
      nixdev.wait_for_open_port(9876)

    with subtest("nixdev io-databases.target reaches active"):
      nixdev.wait_for_unit("io-databases.target")

    with subtest("wait-for-io-databases completed (PG reachable)"):
      nixdev.wait_for_unit("wait-for-io-databases.service")
      out = nixdev.succeed("systemctl show -p ActiveState wait-for-io-databases.service")
      assert "active" in out, f"wait-for-io-databases not active: {out}"

    with subtest("test-dependent service is running (database available)"):
      nixdev.wait_for_unit("test-dependent.service")
      out = nixdev.succeed(
          "systemctl show -p ActiveState,SubState test-dependent.service"
      )
      assert "active" in out, f"test-dependent not active: {out}"
      assert "running" in out, f"test-dependent not running: {out}"

    with subtest("nixdev can connect to remote PostgreSQL on nixio"):
      nixdev.succeed(
          "psql -h nixio -U testuser -d guardian_test -c 'SELECT current_database()'"
      )
      nixdev.succeed(
          "psql -h nixio -U postgres -d guardian_test "
          + "-c 'CREATE TABLE IF NOT EXISTS drain_test (id SERIAL PRIMARY KEY, val TEXT)'"
      )
      nixdev.succeed(
          "psql -h nixio -U postgres -d guardian_test "
          + "-c 'GRANT ALL ON drain_test TO testuser'"
      )
      nixdev.succeed(
          "psql -h nixio -U postgres -d guardian_test "
          + "-c 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO testuser'"
      )

    # --- DRAIN PHASE ---
    with subtest("Stop PostgreSQL → coordinator runs drain"):
      nixio.succeed("systemctl stop postgresql.service")
      nixio.sleep(3)

      # Both postgresql and coordinator should now be inactive
      for svc in ["postgresql.service", "io-database-coordinator.service"]:
          out = nixio.succeed(f"systemctl show -p ActiveState {svc}")
          assert "inactive" in out or "deactivating" in out or "failed" in out, \
              f"{svc} should be inactive after stop: {out}"

    # Since coordinator is bound to postgresql, stopping PG stops coordinator.
    # The drain ExecStop fires. We verify on nixdev that test-dependent stopped.
    with subtest("test-dependent service stopped after drain"):
      nixdev.sleep(5)  # Allow drain command to propagate
      out = nixdev.succeed("systemctl show -p ActiveState,SubState test-dependent.service 2>/dev/null || echo 'inactive'")
      print(f"test-dependent state after drain: {out}")

      # Either inactive or failed — definitely not running
      assert "running" not in out, f"test-dependent should not be running after drain: {out}"

    # --- UNDRAIN PHASE (restart) ---
    with subtest("Restart PostgreSQL → coordinator sends undrain again"):
      nixio.succeed("systemctl start postgresql.service")
      nixio.sleep(2)
      # Start coordinator explicitly — bindsTo/partOf stop the coordinator
      # when postgresql stops, but don't auto-start it when PG comes back
      nixio.succeed("systemctl start io-database-coordinator.service")
      nixio.sleep(5)

    with subtest("Services restart and database is available again"):
      nixdev.wait_for_unit("io-databases.target")
      nixdev.wait_for_unit("wait-for-io-databases.service")
      out = nixdev.succeed(
          "systemctl show -p ActiveState,SubState test-dependent.service"
      )
      print(f"test-dependent state after restart: {out}")
      assert "active" in out, f"test-dependent not active after restart: {out}"
      assert "running" in out, f"test-dependent not running after restart: {out}"

      # Verify DB connectivity still works
      nixdev.succeed(
          "psql -h nixio -U testuser -d guardian_test "
          + "-c \"INSERT INTO drain_test (val) VALUES ('lifecycle-test')\""
      )
      out = nixdev.succeed(
          "psql -h nixio -U testuser -d guardian_test -t -A "
          + "-c \"SELECT val FROM drain_test WHERE id=1\""
      )
      assert out.strip() == "lifecycle-test", (
          f"Expected lifecycle-test, got '{out.strip()}'"
      )

    with subtest("All nodes clean — no failed units"):
      for node in [nixio, nixdev]:
          out = node.succeed("systemctl list-units --state=failed --no-legend --no-pager")
          assert out.strip() == "", f"Failed units on {node.name}: {out}"
  '';
}

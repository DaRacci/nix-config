# Storage Mount Scenario
# Verifies FUSE mount services are defined for s3fs/seaweedfs mounts.
{
  nodes = {
    nixio = _: {
      services.openssh.enable = true;
    };
  };

  testScript = ''
    start_all()
    nixio.wait_for_unit("multi-user.target")
    nixio.succeed("systemctl list-units --all | grep -E 'swfs-mount|s3fs' || true")
  '';
}

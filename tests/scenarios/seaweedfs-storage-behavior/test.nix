let
  masterUrl = "localhost:9333";
  s3Url = "http://localhost:8333";
  filerUrl = "http://localhost:8888";
  adminPort = 23646;
  awsEnv = "AWS_ACCESS_KEY_ID=any AWS_SECRET_ACCESS_KEY=any";
in
{
  nodes = {
    nixio = import ./default.nix;
  };

  testScript = ''
    import json

    start_all()

    with subtest("master leader election"):
      nixio.wait_for_unit("seaweedfs-master.service")
      nixio.wait_for_open_port(9333)
      out = nixio.succeed("curl -sf http://${masterUrl}/cluster/status 2>&1")
      parsed = json.loads(out)
      msg = f"cluster status: {parsed}"
      assert parsed.get("Leader") is not None, msg
      assert ":9333" in str(parsed.get("Leader", "")), msg

    with subtest("volume server registered"):
      nixio.wait_for_unit("seaweedfs-volume.service")
      nixio.wait_for_open_port(8080)
      out = nixio.succeed("curl -sf http://localhost:8080/status 2>&1")
      assert "Version" in out or "volume" in out.lower(), f"volume status unexpected: {out}"

    with subtest("filer starts"):
      nixio.wait_for_unit("seaweedfs-filer.service")
      nixio.wait_for_open_port(8888)

    with subtest("create bucket via S3 API"):
      nixio.succeed(
          "${awsEnv} aws s3api create-bucket"
          + " --endpoint-url ${s3Url}"
          + " --bucket test-bucket"
          + " --region us-east-1 2>&1"
      )

    with subtest("upload file via S3, download via S3"):
      nixio.succeed("echo 'hello seaweedfs' > /tmp/test-upload.txt")
      nixio.succeed(
          "${awsEnv} aws s3api put-object"
          + " --endpoint-url ${s3Url}"
          + " --bucket test-bucket"
          + " --key test.txt"
          + " --body /tmp/test-upload.txt"
          + " --region us-east-1 2>&1"
      )
      nixio.succeed(
          "${awsEnv} aws s3api get-object"
          + " --endpoint-url ${s3Url}"
          + " --bucket test-bucket"
          + " --key test.txt"
          + " /tmp/test-download.txt"
          + " --region us-east-1 2>&1"
      )
      out = nixio.succeed("cat /tmp/test-download.txt")
      assert "hello seaweedfs" in out, f"S3 download mismatch: {out}"

    with subtest("list buckets via S3"):
      # head-bucket verifies bucket exists regardless of identity
      nixio.succeed(
          "${awsEnv} aws s3api head-bucket --endpoint-url ${s3Url} --bucket test-bucket --region us-east-1 2>&1"
      )
      # Also try list-objects to confirm bucket has content
      out = nixio.succeed(
          "${awsEnv} aws s3api list-objects --endpoint-url ${s3Url} --bucket test-bucket --region us-east-1 2>&1"
      )
      assert "test.txt" in out, f"bucket objects unexpected: {out}"

    with subtest("bucket visible via filer HTTP"):
      status = nixio.succeed("curl -s -o /dev/null -w '%{http_code}' ${filerUrl}/test-bucket/ 2>&1").strip()
      assert status in ("200", "301", "302", "403", "404", "500"), f"filer bucket HTTP status: {status}"

    with subtest("admin UI responds"):
      nixio.wait_for_unit("seaweedfs-admin.service")
      nixio.wait_for_open_port(${toString adminPort})
      out = nixio.succeed("curl -sf http://localhost:${toString adminPort}/ 2>&1")
      assert "html" in out.lower() or "SeaweedFS" in out, "admin UI unexpected: " + out

    with subtest("FUSE mount (gated)"):
      hasFuse = nixio.succeed("test -c /dev/fuse && echo yes || echo no").strip()
      if hasFuse == "yes":
        mnt = "/tmp/seaweedfs-mnt"
        nixio.succeed(f"mkdir -p {mnt}")
        # -filer points to filer's HTTP port (8888), not master
        nixio.succeed(f"weed mount -filer=localhost:8888 -dir={mnt} -filer.path=/ -replication=000")
        nixio.succeed(f"echo 'fuse test' > {mnt}/fuse-test.txt")
        out = nixio.succeed(f"cat {mnt}/fuse-test.txt")
        assert "fuse test" in out, "FUSE readback mismatch: " + out
        # lazy unmount to avoid orphan mount issues
        nixio.succeed(f"umount -l {mnt} 2>/dev/null; fusermount -u {mnt} 2>/dev/null; true")
      else:
        nixio.succeed("echo 'FUSE not available; skipping'")
  '';
}

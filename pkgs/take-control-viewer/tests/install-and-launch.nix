{
  pkgs,
  take-control-viewer,
}:
pkgs.testers.runNixOSTest {
  name = "take-control-viewer-install-and-launch";

  nodes.machine = {
    # mkWindowsApp unmounts its overlay bottles through the setuid fusermount3 wrapper.
    programs.fuse.enable = true;
    boot.kernelModules = [ "fuse" ];

    environment.systemPackages = [
      pkgs.xvfb
      take-control-viewer
    ];

    virtualisation = {
      cores = 4;
      diskSize = 4096;
      memorySize = 4096;
    };
  };

  testScript = ''
    from datetime import timedelta

    machine.wait_for_unit("multi-user.target")

    # mkWindowsApp derives paths inside the prefix from $HOME and $USER.
    # Run as root with fixed values so the test does not depend on a login session.
    machine.succeed("mkdir -p /tmp/tcv-home")

    machine.succeed("Xvfb :99 -screen 0 1280x1024x24 > /tmp/xvfb.log 2>&1 &")
    machine.wait_until_succeeds("test -S /tmp/.X11-unix/X99")

    # First run builds the Windows and app layers and installs the viewer.
    # WA_RUN_APP=0 exits after installation instead of waiting for a remote session.
    machine.succeed(
        "HOME=/tmp/tcv-home USER=test DISPLAY=:99 WA_RUN_APP=0 "
        "take-control-viewer < /dev/null > /tmp/install.log 2>&1",
        timeout=timedelta(hours=1),
    )

    # A poisoned app layer would leave this missing and the launcher would report success anyway.
    machine.succeed(
        "test -x '/tmp/tcv-home/.local/share/take-control-viewer/TakeControlRDLdr.exe'"
    )

    # Second run exercises the fileMap and starts the viewer.
    machine.succeed(
        "HOME=/tmp/tcv-home USER=test DISPLAY=:99 "
        "take-control-viewer < /dev/null > /tmp/run.log 2>&1 &"
    )

    # The bracket keeps pgrep from matching the shell that runs this command.
    machine.wait_until_succeeds(
        "pgrep -f '[T]akeControlRDLdr.exe'",
        timeout=timedelta(minutes=5),
    )

    # fileMap must replace the layer directory with a symlink to the persistent share.
    machine.wait_until_succeeds(
        "find /tmp -maxdepth 8 -type l "
        "-lname /tmp/tcv-home/.local/share/take-control-viewer | grep -q .",
        timeout=timedelta(minutes=1),
    )
  '';
}

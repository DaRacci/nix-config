{
  writeShellApplication,
  coreutils,
  findutils,
  gnugrep,
  kmod,
  pciutils,
  symlinkJoin,
  systemd,
}:
let
  perMachine = writeShellApplication {
    name = "per-machine";
    runtimeInputs = [
      coreutils
      findutils
      systemd
    ];
    text = builtins.readFile ./per-machine.sh;
  };

  windowsIsolationStart = writeShellApplication {
    name = "windows-isolation-start";
    runtimeInputs = [ systemd ];
    text = builtins.readFile ./windows-isolation-start.sh;
  };

  windowsIsolationRelease = writeShellApplication {
    name = "windows-isolation-release";
    runtimeInputs = [ systemd ];
    text = builtins.readFile ./windows-isolation-release.sh;
  };

  detachGpu = writeShellApplication {
    name = "detach-gpu";
    runtimeInputs = [
      coreutils
      findutils
      gnugrep
      kmod
      pciutils
      systemd
    ];
    text = builtins.readFile ./detach-gpu.sh;
  };

  attachGpu = writeShellApplication {
    name = "attach-gpu";
    runtimeInputs = [
      coreutils
      gnugrep
      kmod
      systemd
    ];
    text = builtins.readFile ./attach-gpu.sh;
  };
in
symlinkJoin {
  name = "virtualisation-tools";
  paths = [
    perMachine
    windowsIsolationStart
    windowsIsolationRelease
    detachGpu
    attachGpu
  ];
}

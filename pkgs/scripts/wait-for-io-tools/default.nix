{
  writeShellApplication,
  getent,
  iputils,
  symlinkJoin,
  toybox,
}:
let
  waitForIoScript = writeShellApplication {
    name = "wait-for-io";
    runtimeInputs = [
      getent
      iputils
      toybox
    ];
    text = builtins.readFile ./wait-for-io.sh;
  };

  waitForIoDatabasesScript = writeShellApplication {
    name = "wait-for-io-databases";
    runtimeInputs = [ toybox ];
    text = builtins.readFile ./wait-for-io-databases.sh;
  };
in
symlinkJoin {
  name = "wait-for-io-tools";
  paths = [
    waitForIoScript
    waitForIoDatabasesScript
  ];
}

{
  writeShellApplication,
  getent,
  iputils,
  symlinkJoin,
  toybox,
}:
let
  waitForDbPrimaryScript = writeShellApplication {
    name = "wait-for-db-primary";
    runtimeInputs = [
      getent
      iputils
      toybox
    ];
    text = builtins.readFile ./wait-for-db-primary.sh;
  };

  waitForDbDatabasesScript = writeShellApplication {
    name = "wait-for-db-databases";
    runtimeInputs = [ toybox ];
    text = builtins.readFile ./wait-for-db-databases.sh;
  };
in
symlinkJoin {
  name = "wait-for-db-tools";
  paths = [
    waitForDbPrimaryScript
    waitForDbDatabasesScript
  ];
}

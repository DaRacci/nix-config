{
  lib,
  python3Packages,
}:
let
  inherit (lib.maintainers) racci;
  inherit (python3Packages) buildPythonApplication websockets pystemd;

  commonDrv = component: {
    version = "1.2.0";
    pname = "db-guardian-${component}";

    format = "other";
    src = ./.;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp ${./. + "/${component}" + ".py"} $out/bin/db-guardian-${component}
      chmod +x $out/bin/db-guardian-${component}

      runHook postInstall
    '';

    meta = {
      license = lib.licenses.mit;
      maintainers = [ racci ];
      platforms = lib.platforms.linux;
      description = "Database Guardian WebSocket ${component}";
      mainProgram = "db-guardian-${component}";
    };
  };
in
{
  db-guardian-server = buildPythonApplication (
    commonDrv "server"
    // {
      propagatedBuildInputs = [
        websockets
        pystemd
      ];
    }
  );

  db-guardian-client = buildPythonApplication (
    commonDrv "client"
    // {
      propagatedBuildInputs = [ websockets ];
    }
  );
}

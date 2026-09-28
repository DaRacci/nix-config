{
  lib,
  python3Packages,
}:
let
  inherit (python3Packages) buildPythonApplication websockets pystemd;

  commonDrv = component: {
    version = "1.1.0";
    pname = "io-guardian-${component}";

    format = "other";
    src = ./.;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp ${./. + "/${component}" + ".py"} $out/bin/io-guardian-${component}
      chmod +x $out/bin/io-guardian-${component}

      runHook postInstall
    '';

    meta = {
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ racci ];
      platforms = lib.platforms.linux;
      description = "IO Database Guardian WebSocket ${component}";
      mainProgram = "io-guardian-${component}";
    };
  };
in
{
  io-guardian-server = buildPythonApplication (
    commonDrv "server"
    // {
      propagatedBuildInputs = [
        websockets
        pystemd
      ];
    }
  );

  io-guardian-client = buildPythonApplication (
    commonDrv "client"
    // {
      propagatedBuildInputs = [ websockets ];
    }
  );
}

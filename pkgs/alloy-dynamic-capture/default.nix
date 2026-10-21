{
  coreutils,
  lib,
  python3Packages,
  systemd,
  writeShellApplication,
}:
let
  inherit (python3Packages) buildPythonApplication;

  mkPythonTool =
    component: description:
    buildPythonApplication {
      pname = "alloy-dynamic-capture-${component}";
      version = "1.0.0";

      format = "other";
      src = ./.;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        cp ${./. + "/${component}.py"} $out/bin/alloy-dynamic-capture-${component}
        chmod +x $out/bin/alloy-dynamic-capture-${component}

        runHook postInstall
      '';

      meta = {
        license = lib.licenses.mit;
        maintainers = with lib.maintainers; [ racci ];
        platforms = lib.platforms.linux;
        inherit description;
        mainProgram = "alloy-dynamic-capture-${component}";
      };
    };
in
{
  alloy-dynamic-capture-ctl = writeShellApplication {
    name = "alloy-dynamic-capture-ctl";
    runtimeInputs = [
      coreutils
      systemd
    ];
    text = builtins.readFile ./ctl.sh;
  };

  alloy-dynamic-capture-api = mkPythonTool "api" "Alloy dynamic capture mTLS API";

  alloy-dynamic-capture-relay = mkPythonTool "relay" "Alloy dynamic capture loopback relay for Grafana manual trigger";
}

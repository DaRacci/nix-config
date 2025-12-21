{
  python3Packages,
}:
let
  inherit (python3Packages) buildPythonApplication websockets;
in
{
  io-guardian-server = buildPythonApplication {
    pname = "io-guardian-server";
    version = "1.0.0";
    format = "other";

    src = ./.;

    propagatedBuildInputs = [ websockets ];

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp ${./server.py} $out/bin/io-guardian-server
      chmod +x $out/bin/io-guardian-server

      runHook postInstall
    '';

    meta = {
      description = "IO Database Guardian WebSocket Server";
      mainProgram = "io-guardian-server";
    };
  };

  io-guardian-client = buildPythonApplication {
    pname = "io-guardian-client";
    version = "1.0.0";
    format = "other";

    src = ./.;

    propagatedBuildInputs = [ websockets ];

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp ${./client.py} $out/bin/io-guardian-client
      chmod +x $out/bin/io-guardian-client

      runHook postInstall
    '';

    meta = {
      description = "IO Database Guardian WebSocket Client";
      mainProgram = "io-guardian-client";
    };
  };
}

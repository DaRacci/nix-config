{ image ? "dzikoysk/reposilite"
, version ? "latest"
, persistanceDir
}: {
  services.reposilite = { pkgs, lib, ... }: {
    service = {
      image = "${image}:${version}";
      volumes = [ "${persistanceDir}/reposilite:/app/data" ];

      environment = {
        JAVA_OPTS = "-Xmx256M";
        REPOSILITE_OPTS = "--port 8080";
      };
    };
  };
}

{
  image ? "dzikoysk/reposilite",
  version ? "latest",
  persistenceDir,
}:
{
  services.reposilite = _: {
    service = {
      image = "${image}:${version}";
      volumes = [ "${persistenceDir}/reposilite:/app/data" ];

      environment = {
        JAVA_OPTS = "-Xmx256M";
        REPOSILITE_OPTS = "--port 8080";
      };
    };
  };
}

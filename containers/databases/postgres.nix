{ image ? "postgres"
, version ? "latest"
, POSTGRES_USER ? "root"
, POSTGRES_PASSWORD ? "postgres"
}: {
  services.postgres = { pkgs, lib, ... }: {
    service = {
      image = "${image}:${version}";

      environment = { inherit POSTGRES_USER POSTGRES_PASSWORD; };
    };
  };
}

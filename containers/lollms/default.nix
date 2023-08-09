let
  persistDirectory = "/persist/srv/lollms";
in
{
  services.lollms = { pkgs, lib, ... }: {
    image = {
      enableRecommendedContents = true;
      command = [ "${pkgs.lollms-webui}/bin/lollms-webui" "--host" "0.0.0.0" "--port" "9600" "--db_path" "/data/database.db" ];
      contents = [ pkgs.git ];
    };

    service = {
      # useHostStore = true;
      working_dir = "/srv";

      volumes = let containerDirectory = "/srv"; in [
        "${persistDirectory}/models:${containerDirectory}/models"
        "${persistDirectory}/configs:${containerDirectory}/configs"
        "${persistDirectory}/data:${containerDirectory}/help"
        "${persistDirectory}/data:${containerDirectory}/data"
        "${persistDirectory}/data/.pariseno:/root/.pariseno"
      ];

      #       - ./data:/srv/help
      # - ./data:/srv/data
      # - ./data/.parisneo:/root/.parisneo/
      # - ./configs:/srv/configs
      # - ./web:/srv/web

      networks = [ "proxy" ];
      ports = [ "9600:9600/tcp" ];
    };
  };
}

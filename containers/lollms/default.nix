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
      working_dir = "/opt/lollms";

      volumes = let containerDirectory = "/root/Documents/lollms"; in [
        "${persistDirectory}/models:${containerDirectory}/models"
        "${persistDirectory}/configs:${containerDirectory}/configs"
        "${persistDirectory}/models:${containerDirectory}/assets"
        "${persistDirectory}/data:${containerDirectory}/data"
      ];

      networks = [ "proxy" ];
      ports = [ "9600:9600/tcp" ];
    };
  };
}

{
  config,
  ...
}:
{
  sops.secrets = {
    CF_CERT = {
      sopsFile = ./cert.pem;
      format = "binary";
      restartUnits = [ "cloudflared.service" ];
    };

    CF_CREDS = {
      sopsFile = ./credentials.json;
      key = "";
      format = "json";
      restartUnits = [ "cloudflared.service" ];
    };
  };

  services.cloudflared = {
    enable = true;
    certificateFile = config.sops.secrets.CF_CERT.path;
    tunnels = {
      "8d42e9b2-3814-45ea-bbb5-9056c8f017e2" = {
        credentialsFile = config.sops.secrets.CF_CREDS.path;
        default = "http_status:404";
        ingress = {
          "test.racci.dev" = "https://nc.racci.dev";
        };
      };
    };
  };
}

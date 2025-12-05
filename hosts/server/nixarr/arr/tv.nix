{
  nixarr = {
    sonarr = {
      enable = true;
      vpn.enable = true;
    };

    recyclarr.configuration.sonarr = {
      enable = true;
      anime-sonarr-v4 = {
        base_url = "https://sonarr.racci.dev";
        api_key = "!env_var SONARR_API_KEY";

        delete_old_custom_formats = true;
        replace_existing_custom_formats = true;

        include = [
          { template = "sonarr-quality-definition-anime"; }
          { template = "sonarr-v4-quality-profile-anime"; }
          { template = "sonarr-v4-custom-formats-anime"; }
        ];
      };

      web-1080p-v4 = {
        base_url = "https://sonarr.racci.dev";
        api_key = "!env_var SONARR_API_KEY";

        include = [
          { template = "sonarr-quality-definition-series"; }
          { template = "sonarr-v4-quality-profile-web-1080p"; }
          { template = "sonarr-v4-custom-formats-web-1080p"; }
        ];

        custom_formats = [
          # Unwatned
          {
            trash_ids = [
              "85c61753df5da1fb2aab6f2a47426b09" # BR-DISK
              "9c11cd3f07101cdba90a2d81cf0e56b4" # LQ
            ];
            assign_scores_to = [
              {
                name = "WEB-1080p";
                score = -10000;
              }
            ];
          }
          {
            trash_ids = [
              "47435ece6b99a0b477caf360e79ba0bb"
              "9b64dff695c2115facf1b6ea59c9bd07"
            ];
            assign_scores_to = [
              {
                name = "WEB-1080p";
                score = 0;
              }
            ];
          }
        ];
      };
    };
  };

  server.proxy.virtualHosts.sonarr.extraConfig = ''
    reverse_proxy localhost:8989
  '';
}

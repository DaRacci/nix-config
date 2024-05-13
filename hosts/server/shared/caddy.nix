{ pkgs, ... }: {
  services.caddy = {
    package = pkgs.caddy;
    email = "admin@racci.dev";

    # globalConfig = ''
    # log /srv/o.tld/log/log {
    #   rotate_size 50  # Rotate after 50 MB
    #   rotate_age  90  # Keep rotated files for 90 days
    #   rotate_keep 20  # Keep at most 20 log files
    #   rotate_compress # Compress rotated log files in gzip format
    # }
    # '';
  };
}

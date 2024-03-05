let
  image = "adguard/adguardhome:latest";
in
{
  services.adguardhome = { pkgs, lib, ... }: {
    service = {
      inherit image;
      volumes = [
        "/persist/srv/adguardhome/work:/opt/adguardhome/work"
        "/persist/srv/adguardhome/conf:/opt/adguardhome/conf"
      ];

      networks = [ "proxy" "outside" ];
      expose = [
        "53/tcp"
        "53/udp"
        "80/tcp"
        "443/tcp"
        "3000/tcp"
      ];
    };
  };
}

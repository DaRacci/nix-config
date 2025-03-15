{
  name ? "ESP",

  ...
}:
{
  inherit name;

  priority = 1;
  size = "512M";
  type = "EF00";
  content = {
    type = "filesystem";
    format = "vfat";
    mountpoint = "/boot";
    mountOptions = [ "defaults" ];
  };
}

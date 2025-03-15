{
  size ? "2G",

  ...
}:
{
  fsType = "tmpfs";
  mountOptions = [
    "size=${size}"
    "defaults"
    "mode=755"
  ];
}

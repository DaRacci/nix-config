{ size }:
{
  fsType = "tmpfs";
  mountOptions = [
    "size=${toString size}G"
    "defaults"
    "mode=755"
  ];
}

{
  self,
  hostName,
  allocations,
}:
{ ... }: {
  imports = [
    (import "${self}/modules/flake/apply/system.nix" {
      inherit allocations hostName;
      deviceType = "server";
    })
  ];
}

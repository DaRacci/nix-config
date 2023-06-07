{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    fan2go
  ];
}
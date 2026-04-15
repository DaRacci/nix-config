{
  audio = import ./audio.nix;
  programs = import ./programs;
  custom = import ./custom;
  user = import ./user;
  purpose = import ./purpose;
  security = import ./security;
  services = import ./services;
}

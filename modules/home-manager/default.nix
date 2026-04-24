{
  audio = import ./audio.nix;
  programs = import ./programs;
  core = import ./core;
  user = import ./user;
  purpose = import ./purpose;
  security = import ./security;
  services = import ./services;
}

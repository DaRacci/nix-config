{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = with inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}; [ winapps ];

  user.files.persistence.directories = [
    ".config/winapps"
    ".local/share/winapps"
    ".local/share/applications" # winapps puts its desktop files here
  ];
}

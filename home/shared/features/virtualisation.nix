{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = with inputs.winapps.packages.${pkgs.stdenv.system}; [ winapps ];

  user.persistence.directories = [
    ".config/winapps"
    ".local/share/winapps"
  ];
}

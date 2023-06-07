{
  programs.zoxide.enable = true;

  home.persistence."/persist/home/racci".directories = [
    ".local/share/zoxide/db.zo"
  ];
}
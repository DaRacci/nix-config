{ persistenceDirectory, ... }: {
  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/Steam"
  ];

  # TODO :: Force restart steam on rebuild if its open
  # TODO :: Block switch if steam has game open
}

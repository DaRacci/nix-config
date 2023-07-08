{ persistencePath, ... }: {
  home.persistence."${persistencePath}".directory = [
    ".local/share/Steam"
  ];

  # TODO :: Force restart steam on rebuild if its open
  # TODO :: Block switch if steam has game open
}

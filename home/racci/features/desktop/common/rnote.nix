{ pkgs, , ... }: {
  home.packages = with pkgs; [ rnote ];
  user.persistence.directories = [
    # TODO
  ];
}

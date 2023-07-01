let
  directory = "Nextcloud - James";
in {
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  home.persistence."/persist/home/racci".directories = [
    ".config/Nextcloud"
    "${directory}"
  ];

  home.file = {
    Documents = {
      source = "Documents";
      target = "${directory}/Documents";
    };
    Pictures = {
      source = "Pictures";
      target = "${directory}/Pictures";
    };
    Templates = {
      source = "Templates";
      target = "${directory}/Templates";
    };
  };
}
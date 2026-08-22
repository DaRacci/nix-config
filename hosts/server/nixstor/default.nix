_: {
  server.dashboard = {
    icon = "mdi-harddisk";
    items = {
      seaweedfs = {
        title = "SeaweedFS";
        icon = "mdi-file-tree";
      };
    };
  };

  services.metrics = {
    upgradeStatus.enable = false;
    hacompanion.enable = false;
  };
}

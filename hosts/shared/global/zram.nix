{
  zramSwap = {
    enable = true;
    priority = 5;
    algorithm = "zstd";
    memoryMax = null;
    memoryPercent = 50;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };
}

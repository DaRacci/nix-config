_: {
  networking = {
    enableIPv6 = true;

    firewall = {
      # Wireguard Fix
      checkReversePath = "loose";

      logRefusedConnections = false;
      logRefusedPackets = false;
      logReversePathDrops = false;
    };
  };
}

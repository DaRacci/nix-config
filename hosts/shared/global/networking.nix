_: {
  networking = {
    enableIPv6 = true;

    firewall = {
      # Wireguard Fix
      checkReversePath = "loose";

      logRefusedConnections = true;
      logRefusedPackets = true;
      logReversePathDrops = true;
    };
  };
}

{ ... }: {
  networking = {
    enableIPv6 = false; #? TODO :: Learn IPv6 
    nameservers = [ "9.9.9.9" "1.1.1.1" "1.0.0.1" ];

    firewall = {
      # Wireguard Fix
      checkReversePath = "loose";

      logRefusedConnections = true;
      logRefusedPackets = true;
      logReversePathDrops = true;
    };
  };
}

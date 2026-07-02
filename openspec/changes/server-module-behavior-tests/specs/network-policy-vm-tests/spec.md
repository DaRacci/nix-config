## ADDED Requirements

### Requirement: Subnet-scoped firewall rules allow only declared TCP and UDP ports per host

The system SHALL, for each host in `modules/nixos/server/network.nix`, generate `nftables` or `iptables` rules that allow inbound traffic only on the ports declared in that host's `allowedTCPPorts` and `allowedUDPPorts` configuration. The test SHALL verify this from a neutral observer host within the same subnet, not via self-inspection (which `firewall-port-audit` already covers).

#### Scenario: Host allows only declared TCP ports from within the same subnet

- **GIVEN** a multi-node VM topology with a target host (`nixio` declaring `allowedTCPPorts = [ 80 443 9090 ]`), a probe host (`nixcloud`) on the same subnet, and a probe host (`nixai`) on a different subnet
- **WHEN** the probe host on the same subnet attempts TCP connections to each port on `nixio`
- **THEN** connections to ports 80, 443, and 9090 SHALL succeed
- **AND** connections to any other port (e.g., 22, 3306, 8080) SHALL fail (connection refused or timeout)
- **AND** the test SHALL assert by attempting actual TCP connections, not by inspecting nftables ruleset text

#### Scenario: Host allows only declared UDP ports from within the same subnet

- **GIVEN** the same topology with `allowedUDPPorts = [ 51820 ]`
- **WHEN** the probe host sends UDP packets to each declared and undeclared port
- **THEN** packets to port 51820 SHALL reach the target (or not receive ICMP unreachable)
- **AND** packets to undeclared UDP ports SHALL receive ICMP unreachable or be silently dropped

### Requirement: Cross-host rule consistency ensures paired hosts produce identical firewall policies

The system SHALL, when two hosts are declared in the same subnet with identical `allowedTCPPorts` and `allowedUDPPorts`, produce identical rendered firewall rulesets on both hosts. This validates that the rule generation function in `network.nix` is deterministic and symmetric for paired hosts.

#### Scenario: Paired hosts in same subnet produce identical rulesets

- **GIVEN** two hosts (`nixcloud`, `nixdev`) sharing a subnet and declaring identical `allowedTCPPorts = [ 80 443 ]`
- **WHEN** the test inspects the active nftables ruleset on both hosts (`nft list ruleset`)
- **THEN** the rulesets on both hosts SHALL be semantically identical for zone/interface rules covering the shared subnet
- **AND** any differences SHALL be limited to host-specific metadata (e.g., IP address literals within the rule text), not to port allow/deny logic

#### Scenario: Differing port declarations produce distinct rulesets

- **GIVEN** two hosts in the same subnet where `nixcloud` declares `allowedTCPPorts = [ 80 ]` and `nixdev` declares `allowedTCPPorts = [ 443 ]`
- **WHEN** the test inspects the nftables rulesets
- **THEN** `nixcloud`'s ruleset SHALL allow port 80 and block port 443
- **AND** `nixdev`'s ruleset SHALL allow port 443 and block port 80

### Requirement: Host outside the declared subnet cannot reach internal ports

The system SHALL apply subnet-scoped rules such that a host not belonging to the target's subnet is blocked from reaching the target's allowed ports on the subnet-facing interface. This validates that the subnet-scoping mechanism (e.g., `ip saddr` matches, interface binding, or zone separation) is effective.

#### Scenario: Cross-subnet traffic to internal ports is blocked

- **GIVEN** a target host (`nixio`) on subnet `10.10.0.0/24` allowing TCP port 80, and a remote host (`nixai`) on subnet `10.20.0.0/24`
- **WHEN** `nixai` attempts a TCP connection to `nixio:80` 
- **THEN** the connection SHALL fail (timeout or reject)
- **AND** `nixcloud` (on the same subnet as `nixio`) SHALL still be able to connect to `nixio:80` (confirming the rule is subnet-scoped, not globally applied)

#### Scenario: Cross-subnet block does not affect same-subnet traffic

- **GIVEN** the same topology
- **WHEN** `nixcloud` (same subnet as `nixio`) connects to `nixio:80`
- **THEN** the connection SHALL succeed
- **AND** the test SHALL confirm same-subnet connectivity is preserved even while cross-subnet access is blocked

### Requirement: Rule generation in network.nix is deterministic from declarative host metadata

The system SHALL generate firewall rules solely from the host's `server.networking` attributes (or equivalent declarative metadata in `modules/nixos/server/network.nix`), without side-effect-dependent logic. The test SHALL verify that the ruleset is reproducible across VM reboots and that any host metadata change produces the expected rule change.

#### Scenario: Ruleset is reproducible across reboot

- **GIVEN** a host with a fixed `allowedTCPPorts` declaration
- **WHEN** the test captures the ruleset, reboots the host, and re-captures
- **THEN** the pre-reboot and post-reboot rulesets SHALL be identical for all rules derived from the module

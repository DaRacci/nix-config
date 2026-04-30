## ADDED Requirements

### Requirement: Test nodes use VM-specific compatibility overrides

The system SHALL inject a test-only VM compatibility profile into VM test nodes so Proxmox LXC-specific settings do not prevent evaluation or boot.

#### Scenario: Proxmox LXC assumptions removed for tests
- **WHEN** a server host is evaluated as a VM test node
- **THEN** the VM test profile SHALL disable or replace incompatible Proxmox LXC configuration for that node only

#### Scenario: Production configs remain unchanged
- **WHEN** the VM test framework is added
- **THEN** no production host file under `hosts/server/` SHALL be modified solely to remove LXC behavior for testing

## ADDED Requirements

### Requirement: Evaluation documentation explains scope and constraints

The system SHALL document the SeaweedFS evaluation deployment as a parallel, non-migrating experiment alongside MinIO, including endpoint behavior and secret expectations.

#### Scenario: Documentation linked in summary
- **WHEN** SeaweedFS evaluation documentation is added
- **THEN** it SHALL be linked from `docs/src/SUMMARY.md`

#### Scenario: Documentation warns against replacement assumptions
- **WHEN** a maintainer reads the SeaweedFS documentation
- **THEN** it SHALL state that the change is evaluation-only and does not replace or migrate existing MinIO-backed workloads

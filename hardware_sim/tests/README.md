# Hardware tests

The hardware test suite will own:

- fixed-point encoding, temporal-placement, and arithmetic unit tests;
- offline-weight and target-mantissa examples;
- event-ledger schema/provenance tests;
- Icarus RTL smoke tests;
- bit- and cycle-exact Python/RTL co-simulation fixtures;
- reset, stall, backpressure, and back-to-back transaction tests;
- synthesis/report parser and post-synthesis parity tests;
- a contract-to-test coverage matrix for the canonical configuration.

Tests should use only small checked-in fixtures. They must not run PPL,
calibration, or depend on `../anchors`/`../rebuttal`.

The reviewed arithmetic seed is
`hardware_sim/fixtures/m1_arithmetic_vectors_v3.json`. It has no cycle fields;
M2 owns the first transaction/cycle fixture.

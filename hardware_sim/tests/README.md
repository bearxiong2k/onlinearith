# Hardware tests

The hardware test suite will own:

- fixed-point encoding and arithmetic unit tests;
- offline-weight and target-mantissa examples;
- event-ledger schema/provenance tests;
- Icarus RTL smoke tests;
- bit-exact Python/RTL co-simulation fixtures;
- synthesis/report parser tests.

Tests should use only small checked-in fixtures. They must not run PPL,
calibration, or depend on `../anchors`/`../rebuttal`.


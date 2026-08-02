# Hardware fixtures

Store small deterministic transactions here. Each fixture must identify its
schema version, architecture/config revision, origin (`synthetic` or a frozen
artifact plus checksum), expected numeric output, accepted/completion cycles,
and expected event counts.

Arithmetic-contract vector sets precede the M2 transaction protocol and may
omit cycle/event fields explicitly. The corrected frozen M1 set is
[`m1_arithmetic_vectors_v3.json`](m1_arithmetic_vectors_v3.json); M2 will add
the first cycle-annotated transaction fixture rather than retrofitting timing
into this arithmetic-only schema.

Do not commit full model traces or generated characterization sweeps here.

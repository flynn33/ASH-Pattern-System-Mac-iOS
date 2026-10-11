# Canonical Math Baseline

This page summarizes the canonical research-aligned math baseline used by the ASH Pattern System.

## Core Definitions

| Concept | Canonical definition |
|---|---|
| State space | `F2^9` (full 9-bit binary space, 512 states) |
| State vector | `(b0..b8)` with each `bi in F2` |
| Canonical transform | `x' = x XOR c`, `c in C subset F2^9` |
| Codeword set size | 16 members |
| Code parameters | `[9, 4, 4]` doubly-even linear code |
| Averaging operator | `T f(x) = (1/|C|) sum f(x XOR c)` |
| Averaging property | `T^2 = T` (idempotent projection) |
| Branching status | First-class canonical capability |

## Codeword Set Overview

The canonical codeword set `C` is fully closed and fixed.

- Size: 16 codewords
- Construction: XOR-closure of 4 independent generators
- Weight distribution: `{0: 1, 4: 14, 8: 1}`
- Orbit count: `512 / 16 = 32`

Reference: immutable canonical 1.0.0-rc.3 at `50d7e5ab88932a4a967ffc2c83bd18fae45b73c8`; local spec bodies are historical. SDK version is independently 1.0.0-rc.1.

## Critical Invariants

1. Full 9-coordinate processing is required.
2. No coordinate is foundationally privileged.
3. Transforms are deterministic and pure.
4. Same codeword applied twice returns original state.
5. The codeword set is fixed and non-extensible.

## Superseded Model Boundary

The legacy 8+1 interpretation is historical only and must not be used as canonical authority for implementation behavior.

## Related Pages

- [Specification Layers](Specification-Layers)
- [Recovery and Safety Semantics](Recovery-and-Safety-Semantics)
- [Contracts and Verification](Contracts-and-Verification)

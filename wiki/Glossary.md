# Glossary

## ASH State
A full 9-bit vector in `F2^9`.

## Codeword Set (C)
Canonical fixed 16-member subset of `F2^9` used for XOR transformations.

## XOR-by-Codeword
Canonical state motion rule: `x' = x XOR c`.

## Admissibility
Deterministic status assignment for a 9-bit state relative to codeword orbit structure.

## System-State Class
Operational class (`STABLE`, `UNSTABLE`, `CORRECTABLE`, `DEGRADED`, `CONTAINED`, `FAILED`, `SAFE_HALT`).

## Recovery Category
Deterministic action class selected from system-state class.

## Fallback Registry
Canonical policy registry that orders and validates fallback candidates.

## Containment
Restricted operation mode preventing propagation when recovery/fallback is insufficient.

## Safe Halt
Intentional terminal state with preserved diagnostic chain.

## Diagnostic Envelope
Shared schema for all diagnostic records across detection, recovery, escalation, and terminal stages.

## Rule ID Taxonomy
Canonical naming/governance format for diagnostic rule IDs.

## Materialization Boundary
Locked separation between planning (`GenerationPlanner`) and artifact materialization (`ArtifactEmitter`).

## Conformance Categories
Five required verification buckets for Mac/iOS acceptance.

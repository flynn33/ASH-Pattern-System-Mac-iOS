# Realm Identity — canonical specification (Research Baseline)

> **Realigned in Research Math Realignment Package R1.**
> Realm identity now maps from the full 9-bit state / vertex model.
> The previous encoding based on separate "stabilized 8-bit core + derived control bit" is superseded.

## Purpose

Realm identity is the stable semantic encoding of an ASH state.
It provides a deterministic identifier for a state (vertex) in the F2^9 state space.

Each of the 512 states in F2^9 corresponds to a realm. Realm identity encodes this correspondence.

## Inputs

Realm identity is derived from a **full 9-bit ASH state** in F2^9.

## Realm record

```text
TYPE RealmIdentity
    state_signature: String
    realm_id: String
END TYPE
```

The realm record encodes the full 9-bit state as a single signature. There is no separate "core signature" and "control signature" — the full state is the identity source.

## Semantic rule

The same ASH state must always yield the same realm identity.
Different states must yield different realm identities unless the system deliberately defines an equivalence relation that merges them.

## Pseudocode

```text
FUNCTION encode_realm_identity(state: AshState) -> RealmIdentity
    PRECONDITION: state.bits has length 9
    PRECONDITION: all elements are in F2

    realm.state_signature = encode_state_signature(state.bits)
    realm.realm_id = derive_realm_id(realm.state_signature)

    RETURN realm
END FUNCTION
```

## Notes

This specification intentionally leaves the external string format open.
The Apple implementation may use different formatting conventions so long as the mapping remains deterministic and semantically faithful.

## Required invariants

1. Equal states yield equal realm identities
2. Realm identity is computed from the full 9-bit state
3. The encoding is deterministic — same input always produces same output
4. All 9 coordinates of the state participate in the identity encoding

## Relation to other specifications

- **ash-state-space.pseudo.md** — defines the canonical F2^9 state space from which realm identity is derived
- **codeword-transformation-semantics.pseudo.md** — codeword transformations map between realms

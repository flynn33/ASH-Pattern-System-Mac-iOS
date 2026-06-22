# Topology Expansion - APS Semantic Contract

## Purpose

Topology expansion describes how the engine grows abstract structure from a seed.
It does not define directories, files, packages, or UI trees.

## Abstract node model

```text
TYPE TopologyNode
    node_id: String
    parent_id: String or null
    depth: Integer
    ordinal: Integer
    branch_kind: Enum(root, continuation, positive, negative)
    path_token: String
END TYPE
```

## Canonical expansion behavior

The canonical expansion behavior is deterministic ternary branching.
For each node, the next generation emits:

- one continuation child
- one positive child
- one negative child

## Pseudocode

```text
FUNCTION expand_once(nodes: List<TopologyNode>) -> List<TopologyNode>
    next_nodes = []

    FOR each node IN nodes
        append(next_nodes, make_child(node, continuation))
        append(next_nodes, make_child(node, positive))
        append(next_nodes, make_child(node, negative))
    END FOR

    assign_stable_ordinals(next_nodes)
    RETURN next_nodes
END FUNCTION
```

```text
FUNCTION generate_topology(depth: Integer, seed_token: String = "F") -> List<TopologyNode>
    current = [make_root(seed_token)]

    REPEAT depth TIMES
        current = expand_once(current)
    END REPEAT

    RETURN current
END FUNCTION
```

## Determinism rule

Equal seed token and equal depth must always produce the same topology output.

## Separation rule

Topology expansion creates abstract structure only.
Semantic role assignment happens later.
Materialization happens after that.

## Required invariants

1. ordering is stable
2. lineage is reconstructible
3. depth is explicit
4. branch kind is explicit
5. output is deterministic for equal inputs

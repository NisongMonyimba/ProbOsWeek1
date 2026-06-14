"""
ProvenanceTracker: causal DAG for ProbOS simulation runs.

Records which parameter values caused which output percentiles.
Enables regulatory-grade audit trails for safety-critical systems.

Memory design note:
    Current implementation uses Python dicts -- adequate for single-run
    audit trails and development (N=5000, n_steps=300 -> ~12M nodes max).

    For production use (N=100,000+ or streaming), replace with CSR
    (Compressed Sparse Row) representation:
        row_ptr : shape (n_nodes+1,)  -- start index of each node's parents
        col_idx : shape (n_edges,)    -- parent node IDs
    This reduces memory from O(N*n_steps*state_dim) dicts to dense arrays.
    See Month 3 C++ kernel plan for the production implementation.

    Pruning strategy (current):
        Only the final timestep nodes and their direct param parents
        are stored. This captures the immediate causal chain without
        storing the full trajectory history.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from numpy.typing import NDArray

from python.src.monte_carlo import MCResult

FloatArray = NDArray[np.float64]


@dataclass
class ProvenanceNode:
    """
    A single node in the causal provenance DAG.

    Attributes
    ----------
    node_id : str
        Unique identifier. Format:
          params:  'param_{name}_p{particle_id}'
          states:  'state_{name}_t{timestep}_p{particle_id}'
    node_type : str
        One of: 'param', 'state'
    name : str
        Human-readable name: 'Ea_SEI', 'T1', etc.
    value : float
        The numeric value of this node.
    timestep : int
        Time step index. -1 for param nodes (timeless).
    particle_id : int
        Which particle this node belongs to.
    parent_ids : list[str]
        IDs of nodes that causally precede this one.
    """

    node_id:    str
    node_type:  str
    name:       str
    value:      float
    timestep:   int
    particle_id: int
    parent_ids: list[str] = field(default_factory=list)


class ProvenanceTracker:
    """
    Records the causal DAG of a Monte Carlo simulation run.

    Usage
    -----
        tracker = ProvenanceTracker()
        tracker.record_from_result(result, param_names, state_names)

        # Query which particles caused the P05 tail
        p05_ids = tracker.query_particles_causing_p05(result, state_idx=0)

        # Query what parameters those particles had
        ancestors = tracker.query_ancestors(p05_ids[0])

        # Serialise for API response
        d = tracker.to_dict()

    Parameters
    ----------
    max_depth : int
        How many timesteps back to trace ancestors. Default 1 (final
        timestep + direct param parents only). Set to -1 for full history
        (memory-intensive for large N and n_steps).
    """

    def __init__(self, max_depth: int = 1) -> None:
        self._nodes:     dict[str, ProvenanceNode] = {}
        self._max_depth = max_depth

    # ------------------------------------------------------------------
    # Recording
    # ------------------------------------------------------------------

    def record_param(
        self,
        name:        str,
        value:       float,
        particle_id: int,
    ) -> str:
        """
        Record a parameter node. Returns the node_id.

        Parameters are timeless (timestep=-1) and have no parents.
        """
        node_id = f"param_{name}_p{particle_id}"
        self._nodes[node_id] = ProvenanceNode(
            node_id    = node_id,
            node_type  = "param",
            name       = name,
            value      = value,
            timestep   = -1,
            particle_id = particle_id,
            parent_ids = [],
        )
        return node_id

    def record_state(
        self,
        name:        str,
        value:       float,
        timestep:    int,
        particle_id: int,
        parent_ids:  list[str],
    ) -> str:
        """
        Record a state variable node with explicit causal parents.

        Parameters
        ----------
        parent_ids : list[str]
            The param nodes and previous state nodes that caused this
            state value. Must be non-empty for meaningful provenance.
        """
        node_id = f"state_{name}_t{timestep}_p{particle_id}"
        self._nodes[node_id] = ProvenanceNode(
            node_id    = node_id,
            node_type  = "state",
            name       = name,
            value      = value,
            timestep   = timestep,
            particle_id = particle_id,
            parent_ids = parent_ids,
        )
        return node_id

    def record_from_result(
        self,
        result:       MCResult,
        param_names:  list[str],
        state_names:  list[str] | None = None,
    ) -> None:
        """
        Populate the DAG from an MCResult.

        Records:
          - One param node per (particle, parameter)
          - One state node per particle for the FINAL timestep only
            (respects max_depth=1 default to limit memory usage)

        Parameters
        ----------
        result : MCResult
            Output of MonteCarloEngine.run().
        param_names : list[str]
            Human-readable parameter names (model.param_names()).
        state_names : list[str] | None
            Human-readable state names. Defaults to ['state_0', ...].
        """
        N        = result.n_particles
        n_steps  = result.n_steps
        sd       = result.trajectories.shape[2]

        if state_names is None:
            state_names = [f"state_{k}" for k in range(sd)]

        for i in range(N):
            # Record all param nodes for particle i
            param_node_ids = []
            for j, pname in enumerate(param_names):
                nid = self.record_param(
                    name        = pname,
                    value       = float(result.params_used[i, j]),
                    particle_id = i,
                )
                param_node_ids.append(nid)

            # Record final state nodes with params as parents
            for k, sname in enumerate(state_names):
                self.record_state(
                    name        = sname,
                    value       = float(result.trajectories[i, n_steps, k]),
                    timestep    = n_steps,
                    particle_id = i,
                    parent_ids  = param_node_ids,
                )

    # ------------------------------------------------------------------
    # Queries
    # ------------------------------------------------------------------

    def query_ancestors(self, node_id: str) -> list[ProvenanceNode]:
        """
        BFS backwards from node_id through parent edges.
        Returns all ancestor nodes up to max_depth levels back.

        Returns empty list if node_id not found.
        """
        if node_id not in self._nodes:
            return []

        visited: set[str]          = set()
        result:  list[ProvenanceNode] = []
        queue:   list[tuple[str, int]] = [(node_id, 0)]

        while queue:
            nid, depth = queue.pop(0)
            if nid in visited:
                continue
            visited.add(nid)

            node = self._nodes.get(nid)
            if node is None:
                continue
            result.append(node)

            # Stop at max_depth (depth 0 = the queried node itself)
            if self._max_depth >= 0 and depth >= self._max_depth:
                continue

            for pid in node.parent_ids:
                if pid not in visited:
                    queue.append((pid, depth + 1))

        return result

    def query_particles_causing_p05(
        self,
        result:    MCResult,
        state_idx: int = 0,
        timestep:  int = -1,
    ) -> list[int]:
        """
        Return particle IDs in the P05 tail for a given state variable.

        Logic (explicit to avoid indexing errors):
          1. final_values = result.trajectories[:, timestep, state_idx]
             shape: (N,) -- one value per particle
          2. p05_threshold = result.percentiles[0, timestep, state_idx]
             (index 0 = P05 in the [P05, P50, P95] axis)
          3. return particle IDs where final_values <= p05_threshold

        Note: 'causing P05' means the particle IS in the P05 tail of
        the output distribution at the given timestep. The causal
        interpretation comes from querying their ancestor param nodes.

        Parameters
        ----------
        result : MCResult
            Output of MonteCarloEngine.run().
        state_idx : int
            Which state variable to use. Default 0 (T1 for battery).
        timestep : int
            Which timestep to use. Default -1 (final timestep).
        """
        final_values   = result.trajectories[:, timestep, state_idx]
        p05_threshold  = result.percentiles[0, timestep, state_idx]
        particle_ids   = np.where(final_values <= p05_threshold)[0]
        return particle_ids.tolist()

    def query_p05_param_values(
        self,
        result:     MCResult,
        param_names: list[str],
        state_idx:  int = 0,
    ) -> dict[str, FloatArray]:
        """
        Return the parameter values for all P05 particles.

        Returns a dict: param_name -> array of values across P05 particles.
        Useful for understanding what parameter combinations drive the tail.
        """
        p05_ids = self.query_particles_causing_p05(result, state_idx)
        return {
            name: result.params_used[p05_ids, j]
            for j, name in enumerate(param_names)
        }

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------

    def to_dict(self) -> dict[str, object]:
        """
        Return a JSON-serialisable representation of the DAG.
        """
        return {
            "n_nodes": len(self._nodes),
            "nodes": [
                {
                    "node_id":    n.node_id,
                    "node_type":  n.node_type,
                    "name":       n.name,
                    "value":      n.value,
                    "timestep":   n.timestep,
                    "particle_id": n.particle_id,
                    "parent_ids": n.parent_ids,
                }
                for n in self._nodes.values()
            ],
        }

    def __len__(self) -> int:
        return len(self._nodes)

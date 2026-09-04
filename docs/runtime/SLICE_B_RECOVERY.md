# Slice B runtime recovery checkpoint

- Worker deploy must use Wrangler v4 because `wrangler.jsonc` is the canonical Worker configuration.
- The fixed acceptance session is extended through migration `20260904000700_extend_slice_b_runtime_window.sql`.
- No production reservation semantics are changed by this recovery checkpoint.

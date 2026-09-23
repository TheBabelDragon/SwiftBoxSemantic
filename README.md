# SwiftBoxSemantic — Phase 0

Implements the frontend contract: SwiftSyntax → hoist → analyze/type-check
→ (captures fused into closure analysis) → normalize diagnostics →
`SBSemanticModel` → deterministic JSON.

## One deliberate deviation from the sketch

State declarations use **`@State var count: Int = 0`**, not `state var count: Int = 0`.
`state` isn't a real Swift declaration modifier, so SwiftSyntax's parser has
nowhere to put it — it would either misparse as a bare identifier
expression or produce a parse-recovery error before semantic analysis ever
runs. `@State` is real, parseable Swift attribute syntax (and matches
SwiftUI's own convention), so it's what `DeclarationHoister` looks for.
Every fixture and test in this package uses `@State`.

## Structural additions beyond the original sketch

- `SBClosureInfo` gained a `body: [SBStatement]` field. The original sketch
  only carried `captures` — enough to know a closure touches `count`, but
  nothing that lets an IR builder reconstruct *what* the closure computes
  (`count += 1` vs. `count -= 1` vs. anything else). `SBStatement` is a
  minimal `.assign` / `.expression` enum, just enough for Phase 0's
  parameterless `() -> Void` action closures.
- `FunctionID` is a distinct `RawRepresentable` type, not a bare `Int`,
  for the same reason `SymbolID` is — so a closure ID and a symbol ID can
  never be silently swapped.
- `SBBuiltinTable` exposes `matches(name:argumentTypes:)` in addition to
  `resolve(...)`, so overload-failure diagnostics can distinguish "unknown
  view", "no matching overload", and "ambiguous" (>1 exact match) instead
  of collapsing all three into one message.

## Passes, and where they actually fuse

The three-phase contract (hoist → analyze/type-check → capture analysis)
is preserved as a *guarantee* — captures are always keyed by `SymbolID`,
never by name — but capture derivation is fused into closure-body analysis
in `ClosureAnalyzer` rather than run as a fully separate walk. Phase 0
closures introduce no local bindings, so every identifier a closure body
resolves is definitionally a capture; a second traversal would just
re-derive what the first one already knew.

## Status

Not compiled or run — this sandbox has no Swift toolchain and no network
access to resolve the `swift-syntax` package dependency. The code is
written against the SwiftSyntax 509.x API surface as best-known from
training data; run `swift build && swift test` locally to verify, and
expect to fix minor API-surface drift (e.g. exact `AttributeListSyntax`
traversal, `StringLiteralSegmentListSyntax.Element` case naming) against
whatever swift-syntax version actually resolves.

## Next step

Do not build `SwiftBoxIR` yet, per the plan. Once `swift test` is green
against the fixtures here, carve `SwiftBoxIR.Types` from what
`SBSemanticModel` actually promises — not before.

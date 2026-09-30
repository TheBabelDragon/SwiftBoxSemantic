# SwiftBoxSemantic — Phase 0

Implements the frontend contract:

```
Aurora.swift
    ↓
SwiftSyntax (syntax-only)
    ↓
hoisting
    ↓
symbol resolution
    ↓
expression type checking
    ↓
builtin resolution
    ↓
closure / capture analysis
    ↓
SBSemanticModel
    ↓
deterministic JSON
```

## Supported state syntax

State declarations use **`@State var count: Int = 0`**.

`@State` is real, parseable Swift attribute syntax (matching SwiftUI convention). The earlier pseudo-syntax `state var …` is **not** used and is not supported.

## Design invariants (Phase 0)

- **SwiftSyntax is syntax-only.** No SwiftSyntax node types appear in the public semantic model (`SBSemanticModel`, `SBType`, `SBSemanticExpression`, etc.).
- **Semantic analysis owns** symbols, types, and captures.
- **Declarations are hoisted** before body / initializer analysis, so forward references to later `@State` bindings resolve.
- **Builtin overload resolution is exact-match only.** No implicit conversions.  
  Supported:
  - `Text(String)`, `Text(Int)`
  - `Button(String, () -> Void)`
  - `VStack(() -> View)`, `HStack(() -> View)`
- **Typed IDs:** `SymbolID` and `FunctionID` are distinct types (never bare `Int` in the model).
- **Closure captures** record `SymbolID` + kind (`.state` for `@State`) and preserve body statements so a future IR builder can reconstruct e.g. `count += 1`.
- **Diagnostics** contain severity, message, file/line/column, optional `symbolID`, and are normalized into deterministic source order.
- **JSON is deterministic:** `SemanticJSON` always encodes with `.prettyPrinted` + `.sortedKeys`. Identical source → byte-for-byte identical JSON. `schemaVersion` is currently **1**.
- **No general type inference.** Unannotated declarations produce the explicit-type diagnostic.
- **SwiftBoxIR does not exist in this repository yet.**

## Local verification

```bash
swift package resolve
swift build
swift test
swift test --parallel
```

The test suite is intended to be deterministic under concurrent execution.

## Status

Phase 0 semantic frontend is implemented against the SwiftSyntax 509.x surface. Minor API-surface drift (attribute traversal, string-segment cases, etc.) may require tiny adjustments against the exact resolved swift-syntax version; the semantic contract itself is stable.

Do **not** start SwiftBoxIR, the VM, hot reload, generics, protocols, optionals, arrays, async, or general inference until this frontend is green on your machine.

## Next step

Once `swift test` is green against the fixtures, design `SwiftBoxIR` from the actual `SBSemanticModel` contract — not before.

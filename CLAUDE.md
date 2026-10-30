# relay

## Git

- Commit after every meaningful change (a finished, working step), without waiting to be asked.

## Naming

- Crisp, short names.
- Struct fields are camelCase (`userData`), not Zig's snake_case.
- Test names describe behaviour, subject implicit, as terse fragments: `socket readable after peer write`, `eof after peer close`. No leading verb, no articles.

## Code

- `src/main` does not import std: use `sys.zig` bindings and builtins (`@byteSwap`, `@bitCast`), and hand-write small helpers. Tests may use std.
- No comments, doc comments included, unless they explain something non-obvious.

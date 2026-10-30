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
- No general-purpose Kqueue wrapper: one was tried and removed (70a35d8). Build on `sys.zig` directly.

## Tests

- `src/test/darwin/sys_*.zig` call `sys.zig` directly and record kernel behaviour. Keep them raw: don't port, move or delete them. Abstractions get their own test files.

## sys.zig

- Every constant gets a trailing comment with its C name: `pub const FILTER: i16 = -10; // EVFILT_USER`. Verify values in `$(xcrun --show-sdk-path)/usr/include`.
- Non-kevent constants are namespaced by C prefix in their own section, before `// --- kevent ---`: `// --- Sockets ---` with `AF.UNIX`, `SOCK.STREAM`.
- Kevent constants are grouped by filter, not by C prefix. Under `// --- Filters ---`, each filter is a namespace that holds its id and its NOTE flags: `USER.FILTER` (EVFILT_USER), `USER.TRIGGER` (NOTE_TRIGGER). Generic flags stay in `EV` (`EV.ADD`). A flag shared by several filters is repeated in each (`READ.LOWAT`, `WRITE.LOWAT`). C's flat EVFILT_/NOTE_ split hides which flags belong to which filter, and NOTE values collide across filters.
- All error code (`__error`, `E`, `errno`) goes under `// --- Errors ---` at the bottom of the file. New externs go above it.

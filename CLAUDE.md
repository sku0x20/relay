# relay

## Git

- Commit after every meaningful change (a finished, working step), without waiting to be asked.

## Naming

- Crisp, short names. No long, descriptive names — for identifiers, files, and tests.
- Test names describe behaviour with the subject implicit, like `it 'validates'`. The system under test is the "it"; don't repeat it in the name.
  - Good: `test "validates"`, `test "rejects empty"`
  - Bad: `test "parser validates input correctly"`

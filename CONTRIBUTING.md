# Contributing

Keep changes focused. Explain what changed and why it was needed.

## Before Making Changes

Read the relevant implementation and tests first. Match the style of neighboring D code.

- Drive sessions, files, and folders live under `source/google/drive/`.
- Gmail messages, threads, and labels live under `source/google/gmail/`.
- Docs and Sheets export support lives under `source/google/docs/` and `source/google/sheets/`.
- Loopback tests live under `source/tests/dummy/`; live tests under `source/tests/live/`.

## Tests

Run the library build and dummy tests before submitting a change.

```sh
dub build --compiler=ldc2 --config=library
dub test --compiler=ldc2 --config=dummy-tests
```

Add or update dummy tests for behavior changes. They run against a local loopback server and need no credentials. The dummy suite currently has a known local failure in the Drive fixture; see [Testing](TESTING.md) for that failure and for the live suite, which is destructive and requires a dedicated test account.

## Documentation

Update the README when public behavior changes. Check examples against the code, including session setup and logout behavior.

## Reporting Issues

Include a minimal example, expected and actual behavior, compiler and DUB versions, and the API involved (Drive, Gmail, Docs, or Sheets). Sanitize logs and never commit `account.json`, `oauth_client.json`, tokens, or other credentials.

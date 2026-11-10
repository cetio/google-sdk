# Testing

Google-SDK has a loopback dummy suite for routine checks and a live suite that talks to a real Google account.

## Prerequisites

Install DUB and a D compiler. The commands here use LDC (`ldc2`). DUB resolves the `conductor` dependency automatically.

## Library Build

```sh
dub build --compiler=ldc2 -c dummy-tests
```

## Dummy Tests

```sh
dub test --compiler=ldc2 -c dummy-tests
```

The `GoogleSdkTestDummy` version starts a local loopback HTTP server and exercises Drive plus Docs and Sheets export behavior without contacting Google. No credentials are needed; the suite does not currently cover Gmail.

## Known Failure

The dummy suite currently fails locally: the Drive fixture throws `JSONValue is not an object` during `session.login()` (observed with LDC 1.42.0). The cause is not yet identified. CI runs the library build with `-c dummy-tests`; it does not execute the suite.

## Live And Full Tests

```sh
dub test --compiler=ldc2 -c live-tests
dub test --compiler=ldc2 -c full-tests
```

> [!WARNING]
> Live tests are destructive. They log into a real Google account, permanently delete any pre-existing Drive folder named `google_sdk_test_explicit` including its contents, and create new files and folders. Run them only against a dedicated test account.

Requirements:

- `account.json` at the repository root, embedded at compile time. It must define a non-empty `expected_email` matching the test account, for example `{"expected_email": "you@example.com"}`.
- `oauth_client.json` at the repository root, read at runtime. This is the OAuth client JSON from Google Cloud Console.

The suite verifies the logged-in identity against `expected_email` before creating or deleting files. `identity.logout()` runs at the end and revokes the granted OAuth tokens. Both credential files are gitignored; never commit them.

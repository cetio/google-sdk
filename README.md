# Google-SDK

[![License](https://img.shields.io/badge/License-AGPL--3-blue)](LICENSE.txt)

Google-SDK is a small D library for Google Drive with pragmatic Docs and Sheets text export helpers. The surface stays direct: authenticate, browse Drive, read or write files, and pull text from Google Docs or Google Sheets without wrapping the API in a large object graph.

## Modules

| Module | Description |
|--------|-------------|
| `google.drive` | Drive-first API surface: `Session`, `Identity`, `Folder`, `File`, `IFile`, and Drive errors. |
| `google.docs` | MIME helpers plus plain-text export for Google Docs files. |
| `google.sheets` | MIME helpers plus CSV export for Google Sheets files. |
| `google` | Convenience entrypoint that re-exports the packages above. |

## Installation

`dub add google-sdk`

For local development in this workspace:

```json
{
    "dependencies": {
        "google-sdk": {
            "path": "../google-sdk"
        }
    }
}
```

## Usage

### Connect To Drive

```d
import conductor.oauth : OAuth;
import google.drive;
import std.file : readText;
import std.json : parseJSON;

auto oauth = OAuth.fromJSON(parseJSON(readText("oauth_client.json")));
auto session = new Session("MyApp", oauth);
auto identity = session.login();
scope (exit) identity.logout();
```

### Browse Files

```d
import google.drive;

Folder[] folders = identity.folders();
File[] files = identity.listFiles("root");
```

### Read Bytes Or Text

```d
import google.drive;

File file = identity.file("drive-file-id");

ubyte[] bytes = file.read();
string text = file.textReadable ? file.text : null;
```

### Docs And Sheets

Google Docs and Google Sheets stay Drive files. The format-specific packages provide small helpers for MIME detection and text export, while `google.drive.File.text` dispatches to them automatically.

```d
import google.docs;
import google.sheets;

assert(google.docs.supports("application/vnd.google-apps.document"));
assert(google.sheets.supports("application/vnd.google-apps.spreadsheet"));
```

## Current Limits

- Docs support is export-only and currently targets plain text.
- Sheets support is export-only and currently targets CSV.
- Other Google Workspace-native formats remain metadata-aware but not text-readable or writable.
- This library does not try to provide full Docs or Sheets editing APIs yet.

## License

Google-SDK is licensed under [AGPL-3.0](LICENSE.txt).

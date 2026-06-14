# Google-SDK

[![License](https://img.shields.io/badge/License-AGPL%20v3-blue)](LICENSE.txt)

> [!WARNING]
> 
> Google-SDK is not a primary focus of mine, and, although I do maintain and occasionally expand upon the library, support may vary.

Google-SDK is a D library for Google Drive and Gmail. It manages OAuth sessions, file browsing, read/write operations, and Gmail messages and labels without requiring large wrapper layers.

## Features

- **Drive**: Authenticate, browse folders and files, read bytes, write bytes, and export Google Workspace-native files.
- **Gmail**: List, get, send, trash, and delete messages and threads. Manage labels and apply them to messages or threads.
- **Docs And Sheets**: Detect MIME types and export Google Docs as plain text or Google Sheets as CSV. `File.text` dispatches automatically when the format is readable.
- **Error Handling**: Typed exceptions for auth, permission, not-found, rate-limit, and protocol errors in both Drive and Gmail.

## Usage

`dub add google-sdk`

Create an OAuth client JSON from the Google Cloud Console and keep it handy.

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
Folder[] folders = identity.folders();
File[] files = identity.listFiles("root");
```

### Read Or Write

```d
File file = identity.file("drive-file-id");

ubyte[] bytes = file.read();
string text = file.textReadable ? file.text : null;

File newFile = new File(identity, "data.txt", "text/plain");
newFile.write(cast(const(ubyte)[])"hello");
```

### Connect To Gmail

```d
import google.gmail;

auto gmailSession = new google.gmail.Session("MyApp", oauth);
auto gmailIdentity = gmailSession.login();
scope (exit) gmailIdentity.logout();
```

### Manage Messages

```d
Message[] inbox = gmailIdentity.messages("label:inbox");
Message msg = gmailIdentity.message(inbox[0].id);

gmailIdentity.trash(msg);
gmailIdentity.modifyLabels(msg, ["SPAM"], ["INBOX"]);
```

### Manage Labels

```d
Label[] allLabels = gmailIdentity.labels();

Label label = new Label();
label.name = "Project-A";
gmailIdentity.create(label);

gmailIdentity.remove(label);
```

### Docs And Sheets

```d
import google.docs;
import google.sheets;

assert(google.docs.supports("application/vnd.google-apps.document"));
assert(google.sheets.supports("application/vnd.google-apps.spreadsheet"));
```

## Scope

- Docs support is export-only and currently targets plain text.
- Sheets support is export-only and currently targets CSV.
- Other Google Workspace-native formats remain metadata-aware but not text-readable or writable.
- This library does not try to provide full Docs or Sheets editing APIs yet.

## License

Google-SDK is licensed under [AGPL-3.0](LICENSE.txt).

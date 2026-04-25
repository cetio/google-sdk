module google.sheets;

import std.string : assumeUTF;

public:

enum mimeType = "application/vnd.google-apps.spreadsheet";
enum exportMimeType = "text/csv";

bool supports(string value)
    => value == mimeType;

string text(I)(I identity, string id)
{
    ubyte[] bytes = identity.session.exportFile(identity, id, exportMimeType).content;
    return bytes is null ? null : bytes.assumeUTF().idup;
}

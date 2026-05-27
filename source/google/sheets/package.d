module google.sheets;

import google.drive.identity : Identity;
import std.string : assumeUTF;

public:

import google.sheets.cell;
import google.sheets.row;
import google.sheets.table;

enum mimeType = "application/vnd.google-apps.spreadsheet";
enum exportMimeType = "text/csv";

bool supports(string value)
    => value == mimeType;

string csv(Identity identity, string id)
{
    ubyte[] bytes = identity.session.exportFile(identity, id, exportMimeType).content;
    return bytes is null ? null : bytes.assumeUTF().idup;
}

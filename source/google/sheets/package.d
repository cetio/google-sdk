module google.sheets;

import google.drive.id : Identity;
import std.string : assumeUTF;

public:

import google.sheets.cell;
import google.sheets.row;
import google.sheets.sheet;

enum mimeType = "application/vnd.google-apps.spreadsheet";
enum exportMimeType = "text/csv";

bool supports(string value)
    => value == mimeType;

string text(Identity identity, string id)
{
    ubyte[] bytes = identity.session.exportFile(identity, id, exportMimeType).content;
    return bytes is null ? null : bytes.assumeUTF().idup;
}

module google.docs;

import std.string : assumeUTF;

public:

enum mimeType = "application/vnd.google-apps.document";
enum exportMimeType = "text/plain";

bool supports(string value)
    => value == mimeType;

string text(I)(I identity, string id)
{
    ubyte[] bytes = identity.session.exportFile(identity, id, exportMimeType).content;
    return bytes is null ? null : bytes.assumeUTF().idup;
}

module gdrive.test.live.utils;

version (GDriveTestLive)
{
    import gdrive : Folder, Identity, Session;
    import conductor.oauth : OAuth;
    import std.exception : enforce;
    import std.file : readText;
    import std.json : parseJSON;
    import std.path : buildPath, dirName;

    public:

    enum liveTestFolderName = "gdrive_test_explicit";
    enum liveExpectedEmail = extractExpectedEmail(import("account.json"));

    static assert(liveExpectedEmail !is null,
        "account.json must define a non-empty `expected_email` field for the live Google Drive test suite.");

    Session makeLiveSession()
    {
        auto clientJson = parseJSON(readText(liveCredentialsPath()));

        return new Session(
            "GDriveD",
            OAuth.fromJSON(clientJson),
        );
    }

    string liveCredentialsPath()
    {
        return repoRootPath("oauth_client.json");
    }

    void assertExpectedIdentity(Identity identity)
    {
        enforce(
            identity.email == liveExpectedEmail,
            "Live Google Drive tests logged into `"~identity.email~"` but account.json requires `" ~
            liveExpectedEmail~"`.",
        );
    }

    Folder recreateTestRoot(Identity identity)
    {
        Folder[] matches;
        foreach (Folder folder; identity.folders())
        {
            if (folder.name == liveTestFolderName)
                matches ~= folder;
        }

        enforce(
            matches.length <= 1,
            "Multiple root folders named `"~liveTestFolderName~"` exist. Remove duplicates before running live tests.",
        );

        if (matches.length == 1)
            identity.removeTree(matches[0]);

        return identity.create(new Folder(identity, liveTestFolderName));
    }

    private:

    string repoRootPath(string relativePath)
    {
        string root = dirName(dirName(dirName(dirName(dirName(__FILE_FULL_PATH__)))));
        return buildPath(root, relativePath);
    }

    size_t findSubstring(string haystack, string needle)
    {
        if (needle.length == 0)
            return 0;
        if (haystack.length < needle.length)
            return size_t.max;

        foreach (size_t index; 0..haystack.length - needle.length + 1)
        {
            bool matched = true;
            foreach (size_t offset; 0..needle.length)
            {
                if (haystack[index + offset] != needle[offset])
                {
                    matched = false;
                    break;
                }
            }

            if (matched)
                return index;
        }

        return size_t.max;
    }

    bool isWhitespace(char ch)
    {
        return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
    }

    string extractExpectedEmail(string json)
    {
        enum expectedEmailKey = "\"expected_email\"";
        size_t keyPos = findSubstring(json, expectedEmailKey);
        if (keyPos == size_t.max)
            return null;

        size_t cursor = keyPos + expectedEmailKey.length;
        while (cursor < json.length && isWhitespace(json[cursor]))
            cursor++;
        if (cursor >= json.length || json[cursor] != ':')
            return null;

        cursor++;
        while (cursor < json.length && isWhitespace(json[cursor]))
            cursor++;
        if (cursor >= json.length || json[cursor] != '"')
            return null;

        size_t start = cursor + 1;
        cursor = start;
        while (cursor < json.length && json[cursor] != '"')
            cursor++;
        if (cursor <= start || cursor > json.length)
            return null;

        return json[start..cursor];
    }
}

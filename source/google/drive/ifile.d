module google.drive.ifile;

interface IFile
{
    string id() const;
    string name() const;
    string mimeType() const;
    string parentId() const;
    ulong sizeBytes() const;
    string modifiedTime() const;
    bool trashed() const;
    string driveId() const;
    string webViewLink() const;
    string md5Checksum() const;

    bool draft() const;
    bool workspaceNative() const;
    bool textReadable() const;

    ubyte[] read();
    void write(const(ubyte)[] data);
    void save(string path);
    string text();
    void refresh();
}

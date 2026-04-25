module google.drive.ifile;

interface IFile
{
    @property string id() const;
    @property string name() const;
    @property string mimeType() const;
    @property string parentId() const;
    @property ulong sizeBytes() const;
    @property string modifiedTime() const;
    @property bool trashed() const;
    @property string driveId() const;
    @property string webViewLink() const;
    @property string md5Checksum() const;

    bool draft() const;
    @property bool workspaceNative() const;
    @property bool textReadable() const;

    ubyte[] read();
    void write(const(ubyte)[] data);
    void save(string path);
    @property string text();
    void refresh();
}

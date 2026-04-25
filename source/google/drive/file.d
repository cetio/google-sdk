module google.drive.file;

import google.docs : googleDocExportMimeType = exportMimeType, googleDocText = text, isGoogleDoc = supports;
import google.drive.errors : GoogleDriveNotFoundError, GoogleDriveProtocolError, GoogleDriveUnsupportedContentError;
import google.drive.folder : folderMimeType;
import google.drive.identity : Identity;
import google.drive.ifile : IFile;
import google.drive.internal.fs : atomicWriteBytes, ensureDirectory;
import google.sheets : googleSheetExportMimeType = exportMimeType, googleSheetText = text, isGoogleSheet = supports;
import std.algorithm.searching : canFind;
import std.conv : to;
import std.json : JSONType, JSONValue;
import std.net.curl : HTTP;
import std.path : dirName, expandTilde;
import std.string : assumeUTF, startsWith;

public:

enum defaultFileMimeType = "application/octet-stream";
enum workspaceMimeTypePrefix = "application/vnd.google-apps.";

class File : IFile
{
public:
    Identity identity;

    this(
        Identity identity,
        string name,
        string mimeType = defaultFileMimeType,
        string parentId = "root",
    )
    {
        this.identity = identity;
        this.name = name;

        if (mimeType != null)
            this.mimeType = mimeType;

        if (parentId != null)
            this.parentId = parentId;
    }

    @property string id() const
        => _id;

    @property void id(string value)
    {
        _id = value;
    }

    @property string name() const
        => _name;

    @property void name(string value)
    {
        _name = value;
    }

    @property string mimeType() const
        => _mimeType;

    @property void mimeType(string value)
    {
        _mimeType = value == null ? defaultFileMimeType : value;
    }

    @property string parentId() const
        => _parentId;

    @property void parentId(string value)
    {
        _parentId = value == null ? "root" : value;
    }

    @property ulong sizeBytes() const
        => _sizeBytes;

    @property void sizeBytes(ulong value)
    {
        _sizeBytes = value;
    }

    @property string modifiedTime() const
        => _modifiedTime;

    @property void modifiedTime(string value)
    {
        _modifiedTime = value;
    }

    @property bool trashed() const
        => _trashed;

    @property void trashed(bool value)
    {
        _trashed = value;
    }

    @property string driveId() const
        => _driveId;

    @property void driveId(string value)
    {
        _driveId = value;
    }

    @property string webViewLink() const
        => _webViewLink;

    @property void webViewLink(string value)
    {
        _webViewLink = value;
    }

    @property string md5Checksum() const
        => _md5Checksum;

    @property void md5Checksum(string value)
    {
        _md5Checksum = value;
    }

    bool draft() const
        => id == null;

    @property bool workspaceNative() const
        => mimeType.startsWith(workspaceMimeTypePrefix) && mimeType != folderMimeType;

    @property bool textReadable() const
    {
        if (isGoogleDoc(mimeType) || isGoogleSheet(mimeType))
            return true;

        return supportsTextMimeType(mimeType);
    }

    bool googleDoc() const
        => isGoogleDoc(mimeType);

    bool googleSheet() const
        => isGoogleSheet(mimeType);

    static File fromJson(Identity identity, JSONValue value)
    {
        File ret = new File(
            identity,
            "name" in value ? value["name"].str : null,
            "mimeType" in value ? value["mimeType"].str : null,
            firstParent(value),
        );
        ret.apply(value);
        return ret;
    }

    void apply(JSONValue value)
    {
        id = "id" in value ? value["id"].str : null;
        name = "name" in value ? value["name"].str : null;
        mimeType = "mimeType" in value ? value["mimeType"].str : null;
        parentId = firstParent(value);
        if ("size" in value)
        {
            switch (value["size"].type)
            {
            case JSONType.uinteger:
                sizeBytes = value["size"].uinteger;
                break;

            case JSONType.integer:
                sizeBytes = cast(ulong)value["size"].integer;
                break;

            case JSONType.string:
                sizeBytes = value["size"].str == null ? 0 : to!ulong(value["size"].str);
                break;

            default:
                sizeBytes = 0;
                break;
            }
        }
        else
            sizeBytes = 0;
        modifiedTime = "modifiedTime" in value ? value["modifiedTime"].str : null;
        trashed = "trashed" in value && value["trashed"].type == JSONType.true_;
        driveId = "driveId" in value ? value["driveId"].str : null;
        webViewLink = "webViewLink" in value ? value["webViewLink"].str : null;
        md5Checksum = "md5Checksum" in value ? value["md5Checksum"].str : null;
    }

    void clearRemote()
    {
        id = null;
        sizeBytes = 0;
        modifiedTime = null;
        trashed = false;
        driveId = null;
        webViewLink = null;
        md5Checksum = null;
    }

    void create()
    {
        if (!draft())
            return;

        if (identity is null)
            throw new GoogleDriveProtocolError("Cannot create a Google Drive file without an identity.");

        JSONValue created = identity.session.createMetadata(
            identity,
            name,
            mimeType == null ? defaultFileMimeType : mimeType,
            parentId,
        );
        apply(created);
    }

    ubyte[] read()
    {
        if (draft())
            return null;

        if (identity is null)
            throw new GoogleDriveProtocolError("Cannot read a Google Drive file without an identity.");

        if (workspaceNative)
        {
            string exportType = exportMimeType();
            if (exportType == null)
                throw new GoogleDriveUnsupportedContentError(
                    "Google Workspace-native files of type `"~mimeType~"` are not readable.",
                );

            try
                return identity.session.exportFile(identity, id, exportType).content;
            catch (GoogleDriveNotFoundError)
            {
                clearRemote();
                return null;
            }
        }

        try
        {
            return identity.session.execute(
                identity,
                false,
                HTTP.Method.get,
                identity.session.filePath(id),
                ["alt": "media"],
            ).content;
        }
        catch (GoogleDriveNotFoundError)
        {
            clearRemote();
            return null;
        }
    }

    void write(const(ubyte)[] data)
    {
        if (identity is null)
            throw new GoogleDriveProtocolError("Cannot write a Google Drive file without an identity.");

        if (workspaceNative)
            throw new GoogleDriveUnsupportedContentError(
                "Google Workspace-native files of type `"~mimeType~"` are not writable.",
            );

        if (draft())
            create();

        try
        {
            JSONValue updated = identity.session.updateFileData(identity, this, data);
            apply(updated);
            return;
        }
        catch (GoogleDriveNotFoundError)
        {
            clearRemote();
        }

        create();
        apply(identity.session.updateFileData(identity, this, data));
    }

    void save(string path)
    {
        ubyte[] bytes = read();
        if (bytes == null)
            throw new GoogleDriveNotFoundError("Google Drive file does not exist in the cloud.");

        string resolvedPath = expandTilde(path);
        string parent = dirName(resolvedPath);
        if (parent != null)
            ensureDirectory(parent);

        atomicWriteBytes(resolvedPath, bytes);
    }

    @property string text()
    {
        if (draft())
            return null;

        if (identity is null)
            throw new GoogleDriveProtocolError("Cannot read Google Drive text without an identity.");

        if (googleDoc())
            return googleDocText(identity, id);

        if (googleSheet())
            return googleSheetText(identity, id);

        if (!supportsTextMimeType(mimeType))
            throw new GoogleDriveUnsupportedContentError(
                "Google Drive file type `"~resolvedMimeType()~"` is not readable as text.",
            );

        ubyte[] bytes = read();
        if (bytes is null)
            return null;

        return bytes.assumeUTF().idup;
    }

    void refresh()
    {
        if (identity is null)
            throw new GoogleDriveProtocolError("Cannot refresh a Google Drive file without an identity.");

        JSONValue value = identity.fetchMetadata(id);
        if (
            value.type == JSONType.null_ ||
            !("mimeType" in value) ||
            value["mimeType"].type != JSONType.string ||
            value["mimeType"].str == folderMimeType
        )
            throw new GoogleDriveNotFoundError("Google Drive file no longer exists.");

        apply(value);
    }

private:
    string _id;
    string _name;
    string _mimeType = defaultFileMimeType;
    string _parentId = "root";
    ulong _sizeBytes;
    string _modifiedTime;
    bool _trashed;
    string _driveId;
    string _webViewLink;
    string _md5Checksum;

    string exportMimeType() const
    {
        if (googleDoc())
            return googleDocExportMimeType;
        if (googleSheet())
            return googleSheetExportMimeType;
        return null;
    }

    string resolvedMimeType() const
    {
        return mimeType == null ? defaultFileMimeType : mimeType;
    }

    static bool supportsTextMimeType(string mimeType)
    {
        if (mimeType == null)
            return false;

        if (mimeType.startsWith("text/"))
            return true;

        enum additionalTextMimeTypes = [
            "application/csv",
            "application/ecmascript",
            "application/javascript",
            "application/json",
            "application/sql",
            "application/toml",
            "application/x-httpd-php",
            "application/x-javascript",
            "application/x-shellscript",
            "application/x-sh",
            "application/x-toml",
            "application/x-yaml",
            "application/xml",
            "application/yaml",
        ];

        return additionalTextMimeTypes.canFind(mimeType);
    }

    static string firstParent(JSONValue value)
    {
        if ("parents" in value && value["parents"].type == JSONType.array)
        {
            JSONValue[] parents = value["parents"].array;
            if (parents.length && parents[0].type == JSONType.string)
                return parents[0].str;
        }

        return "root";
    }
}

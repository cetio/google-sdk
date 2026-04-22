module gdrive.file;

import gdrive.errors : GDriveNotFoundError, GDriveProtocolError, GDriveUnsupportedContentError;
import gdrive.folder : folderMimeType;
import gdrive.identity : Identity;
import gdrive.internal.fs : atomicWriteBytes, ensureDirectory;
import std.conv : to;
import std.json : JSONType, JSONValue;
import std.net.curl : HTTP;
import std.path : dirName, expandTilde;
import std.string : startsWith;

public:

enum defaultFileMimeType = "application/octet-stream";
enum workspaceMimeTypePrefix = "application/vnd.google-apps.";

class File
{
public:
    Identity identity;
    string id;
    string name;
    string mimeType = defaultFileMimeType;
    string parentId = "root";
    ulong sizeBytes;
    string modifiedTime;
    bool trashed;
    string driveId;
    string webViewLink;
    string md5Checksum;

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

    bool draft() const
        => id == null;

    bool workspaceNative() const
        => mimeType.startsWith(workspaceMimeTypePrefix) && mimeType != folderMimeType;

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
            throw new GDriveProtocolError("Cannot create a Google Drive file without an identity.");

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
            throw new GDriveProtocolError("Cannot read a Google Drive file without an identity.");

        if (workspaceNative())
            throw new GDriveUnsupportedContentError("Google Workspace-native files are metadata-only in this version.");

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
        catch (GDriveNotFoundError)
        {
            clearRemote();
            return null;
        }
    }

    void write(const(ubyte)[] data)
    {
        if (identity is null)
            throw new GDriveProtocolError("Cannot write a Google Drive file without an identity.");

        if (workspaceNative())
            throw new GDriveUnsupportedContentError("Google Workspace-native files are metadata-only in this version.");

        if (draft())
            create();

        try
        {
            JSONValue updated = identity.session.updateFileData(identity, this, data);
            apply(updated);
            return;
        }
        catch (GDriveNotFoundError)
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
            throw new GDriveNotFoundError("Google Drive file does not exist in the cloud.");

        string resolvedPath = expandTilde(path);
        string parent = dirName(resolvedPath);
        if (parent != null)
            ensureDirectory(parent);

        atomicWriteBytes(resolvedPath, bytes);
    }

    void refresh()
    {
        if (identity is null)
            throw new GDriveProtocolError("Cannot refresh a Google Drive file without an identity.");

        JSONValue value = identity.fetchMetadata(id);
        if (
            value.type == JSONType.null_ ||
            !("mimeType" in value) ||
            value["mimeType"].type != JSONType.string ||
            value["mimeType"].str == folderMimeType
        )
            throw new GDriveNotFoundError("Google Drive file no longer exists.");

        apply(value);
    }

private:
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

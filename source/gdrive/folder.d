module gdrive.folder;

import gdrive.errors : GDriveNotFoundError, GDriveProtocolError;
import gdrive.file : File;
import gdrive.identity : Identity;
import std.json : JSONType, JSONValue;

public:

enum folderMimeType = "application/vnd.google-apps.folder";

class Folder
{
public:
    Identity identity;
    string id;
    string name;
    string mimeType = folderMimeType;
    string parentId = "root";
    string modifiedTime;
    bool trashed;
    string driveId;
    string webViewLink;

    this(Identity identity, string name, string parentId = "root")
    {
        this.identity = identity;
        this.name = name;

        if (parentId != null)
            this.parentId = parentId;
    }

    bool draft() const
        => id == null;

    static Folder fromJson(Identity identity, JSONValue value)
    {
        Folder ret = new Folder(
            identity,
            "name" in value ? value["name"].str : null,
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
        modifiedTime = "modifiedTime" in value ? value["modifiedTime"].str : null;
        trashed = "trashed" in value && value["trashed"].type == JSONType.true_;
        driveId = "driveId" in value ? value["driveId"].str : null;
        webViewLink = "webViewLink" in value ? value["webViewLink"].str : null;
    }

    void clearRemote()
    {
        id = null;
        modifiedTime = null;
        trashed = false;
        driveId = null;
        webViewLink = null;
    }

    void create()
    {
        if (!draft())
            return;

        if (identity is null)
            throw new GDriveProtocolError("Cannot create a Google Drive folder without an identity.");

        JSONValue created = identity.session.createMetadata(
            identity,
            name,
            folderMimeType,
            parentId,
        );
        apply(created);
    }

    Folder[] folders()
    {
        if (draft())
            return null;

        if (identity is null)
            throw new GDriveProtocolError("Cannot list Google Drive folders without an identity.");

        return identity.listFolders(id);
    }

    File[] files()
    {
        if (draft())
            return null;

        if (identity is null)
            throw new GDriveProtocolError("Cannot list Google Drive files without an identity.");

        return identity.listFiles(id);
    }

    T create(T)(T item)
        if (is(T == Folder) || is(T == File))
    {
        if (item is null)
            return null;

        if (draft())
            create();

        if (item.parentId == "root" || item.parentId == null)
            item.parentId = id;

        return identity.create(item);
    }

    void refresh()
    {
        if (identity is null)
            throw new GDriveProtocolError("Cannot refresh a Google Drive folder without an identity.");

        JSONValue value = identity.fetchMetadata(id);
        if (
            value.type == JSONType.null_ ||
            !("mimeType" in value) ||
            value["mimeType"].type != JSONType.string ||
            value["mimeType"].str != folderMimeType
        )
            throw new GDriveNotFoundError("Google Drive folder no longer exists.");

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

module gdrive.identity;

import composer.oauth : OAuthError, TokenBundle;
import gdrive.errors : GDriveAuthError, GDriveProtocolError;
import gdrive.file : File;
import gdrive.folder : Folder, folderMimeType;
import gdrive.session : Session;
import std.json : JSONType, JSONValue;
import std.net.curl : HTTP;

class Identity
{
public:
    Session session;
    TokenBundle tokens;
    string requestedScope;
    string permissionId;
    string email;
    string displayName;

    this(
        Session session,
        string requestedScope,
        TokenBundle tokens,
    )
    {
        this.session = session;
        this.requestedScope = requestedScope;
        this.tokens = tokens;
    }

    Folder[] folders()
    {
        return listFolders("root");
    }

    Folder[] listFolders(string parentId)
    {
        Folder[] ret;
        foreach (JSONValue item; session.listItemMetadata(this, parentId, true))
            ret ~= Folder.fromJson(this, item);

        return ret;
    }

    File[] listFiles(string parentId)
    {
        File[] ret;
        foreach (JSONValue item; session.listItemMetadata(this, parentId, false))
            ret ~= File.fromJson(this, item);

        return ret;
    }

    JSONValue fetchMetadata(string id)
    {
        return session.fetchMetadata(this, id);
    }

    Folder folder(string id)
    {
        JSONValue value = fetchMetadata(id);
        if (
            value.type == JSONType.null_ ||
            !("mimeType" in value) ||
            value["mimeType"].type != JSONType.string ||
            value["mimeType"].str != folderMimeType
        )
            throw new GDriveProtocolError("The requested Google Drive item is not a folder.");

        return Folder.fromJson(this, value);
    }

    File file(string id)
    {
        JSONValue value = fetchMetadata(id);
        if (
            value.type == JSONType.null_ ||
            !("mimeType" in value) ||
            value["mimeType"].type != JSONType.string ||
            value["mimeType"].str == folderMimeType
        )
            throw new GDriveProtocolError("The requested Google Drive item is a folder, not a file.");

        return File.fromJson(this, value);
    }

    T create(T)(T item)
        if (is(T == Folder) || is(T == File))
    {
        if (item is null)
            throw new GDriveProtocolError("Cannot create a null Google Drive object.");

        if (item.identity !is this)
            throw new GDriveProtocolError("Cannot create a Google Drive object that belongs to a different identity.");

        item.create();
        return item;
    }

    void remove(string id)
    {
        session.deleteItem(this, id);
    }

    void remove(File file)
    {
        if (file is null || file.draft())
            return;

        session.deleteItem(this, file.id);
        file.clearRemote();
    }

    void remove(Folder folder)
    {
        if (folder is null || folder.draft())
            return;

        session.deleteItem(this, folder.id);
        folder.clearRemote();
    }

    void removeTree(Folder folder)
    {
        if (folder is null || folder.draft())
            return;

        foreach (File file; folder.files())
            remove(file);

        foreach (Folder child; folder.folders())
            removeTree(child);

        remove(folder);
    }

    void refresh()
    {
        JSONValue json = session.requestJson(
            this,
            HTTP.Method.get,
            "/drive/v3/about",
            ["fields": "user(displayName,emailAddress,permissionId)"],
        );
        if (!("user" in json) || json["user"].type != JSONType.object)
            throw new GDriveProtocolError("Google Drive did not return the current account.");

        JSONValue user = json["user"];

        permissionId = "permissionId" in user ? user["permissionId"].str : null;
        email = "emailAddress" in user ? user["emailAddress"].str : null;
        displayName = "displayName" in user ? user["displayName"].str : null;
        if (permissionId == null)
            throw new GDriveProtocolError("Google Drive did not return the current account permission ID.");
    }

    void logout()
    {
        session.logout(this);
    }

    bool tryRefresh()
    {
        if (tokens.refreshToken == null)
            return false;

        try
            tokens = session.oauth.refresh(tokens);
        catch (OAuthError err)
            throw new GDriveAuthError(err.msg);

        return true;
    }
}

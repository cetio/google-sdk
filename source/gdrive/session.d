module source.gdrive.session;

import composer.http : Response;
import composer.oauth : OAuth, OAuthError, TokenBundle;
import composer.orchestrate : Orchestrator;
import core.thread : Thread;
import core.time : dur;
import gdrive.errors;
import gdrive.file : defaultFileMimeType, File;
import gdrive.folder : folderMimeType;
import gdrive.identity : Identity;
import std.conv : to;
import std.json : JSONType, JSONValue, parseJSON;
import std.net.curl : HTTP;
import std.random : unpredictableSeed;
import std.string : replace;
import std.uri : encodeComponent;

class Session
{
private:
    enum defaultScope = "https://www.googleapis.com/auth/drive";
    enum listFields =
        "nextPageToken,files(id,name,mimeType,parents,size,modifiedTime,trashed,driveId,webViewLink,md5Checksum)";
    enum itemFields = "id,name,mimeType,parents,size,modifiedTime,trashed,driveId,webViewLink,md5Checksum";

public:
    Orchestrator api;
    Orchestrator upload;
    OAuth oauth;
    string name;

    this(
        string name,
        OAuth oauth,
        string apiUrl = "https://www.googleapis.com",
        string uploadUrl = "https://www.googleapis.com/upload",
    )
    {
        this.name = name == null ? "GDrive" : name;
        this.oauth = oauth;
        this.api = Orchestrator(apiUrl);
        this.upload = Orchestrator(uploadUrl);
    }

    Identity login(string requestedScope = defaultScope)
    {
        Identity ret;

        try
            ret = new Identity(
                this,
                requestedScope,
                oauth.authorize(this.name, requestedScope)
            );
        catch (OAuthError err)
            throw new GDriveAuthError(err.msg);

        ret.refresh();
        return ret;
    }

    void logout(Identity identity)
    {
        if (identity is null || identity.tokens.empty())
            return;

        try
            oauth.revoke(identity.tokens);
        catch (OAuthError err)
            throw new GDriveAuthError(err.msg);

        identity.tokens = TokenBundle.init;
    }

    JSONValue[] listItemMetadata(Identity identity, string parentId, bool foldersOnly)
    {
        JSONValue[] ret;
        string nextPageToken;

        do
        {
            string[string] query;
            query["fields"] = listFields;
            query["pageSize"] = "1000";
            query["q"] = buildListQuery(parentId, foldersOnly);
            query["supportsAllDrives"] = "false";
            if (nextPageToken != null)
                query["pageToken"] = nextPageToken;

            JSONValue json = requestJson(
                identity,
                HTTP.Method.get,
                "/drive/v3/files",
                query,
            );
            if ("files" in json && json["files"].type == JSONType.array)
            {
                foreach (JSONValue item; json["files"].array)
                    ret ~= item;
            }

            nextPageToken = "nextPageToken" in json ? json["nextPageToken"].str : null;
        }
        while (nextPageToken != null);

        return ret;
    }

    JSONValue fetchMetadata(Identity identity, string id)
    {
        return requestJson(
            identity,
            HTTP.Method.get,
            filePath(id),
            [
                "fields": itemFields,
                "supportsAllDrives": "false",
            ],
        );
    }

    JSONValue createMetadata(
        Identity identity,
        string name,
        string mimeType,
        string parentId,
    )
    {
        JSONValue payload = JSONValue.emptyObject;
        payload["name"] = JSONValue(name);
        payload["mimeType"] = JSONValue(mimeType);
        payload["parents"] = JSONValue.emptyArray;
        payload["parents"].array ~= JSONValue(parentId == null ? "root" : parentId);

        return requestJson(
            identity,
            HTTP.Method.post,
            "/drive/v3/files",
            [
                "fields": itemFields,
                "supportsAllDrives": "false",
            ],
            cast(const(ubyte)[])payload.toString().dup,
            "application/json; charset=UTF-8",
        );
    }

    JSONValue updateFileData(Identity identity, File file, const(ubyte)[] data)
    {
        string boundary = "gdrive-"~unpredictableSeed!ulong.to!string;
        string mimeType = file.mimeType == null ? defaultFileMimeType : file.mimeType;

        string prefix =
            "--"~boundary~"\r\n" ~
            "Content-Type: application/json; charset=UTF-8\r\n\r\n" ~
            "{}\r\n" ~
            "--"~boundary~"\r\n" ~
            "Content-Type: "~mimeType~"\r\n\r\n";
        string suffix = "\r\n--"~boundary~"--\r\n";

        ubyte[] content;
        content ~= cast(const(ubyte)[])prefix;
        content ~= data;
        content ~= cast(const(ubyte)[])suffix;

        return requestJson(
            identity,
            HTTP.Method.patch,
            filePath(file.id),
            [
                "uploadType": "multipart",
                "fields": itemFields,
                "supportsAllDrives": "false",
            ],
            content,
            "multipart/related; boundary="~boundary,
            true,
        );
    }

    void deleteItem(Identity identity, string id)
    {
        execute(
            identity,
            false,
            HTTP.Method.del,
            filePath(id),
        );
    }

    JSONValue requestJson(
        Identity identity,
        HTTP.Method method,
        string path,
        string[string] query = null,
        const(ubyte)[] content = null,
        string contentType = null,
        bool useUploadEndpoint = false,
    )
    {
        Response response = execute(
            identity,
            useUploadEndpoint,
            method,
            path,
            query,
            content,
            contentType,
        );
        return response.content == null ? JSONValue.init : parseJSON(cast(string)response.content);
    }

    Response execute(
        Identity identity,
        bool useUploadEndpoint,
        HTTP.Method method,
        string path,
        string[string] query = null,
        const(ubyte)[] content = null,
        string contentType = null,
    )
    {
        ensureAuthorized(identity);

        string[string] headers;
        headers["Authorization"] = "Bearer "~identity.tokens.accessToken;
        if (name != null)
            headers["User-Agent"] = name;

        foreach (int attempt; 0..5)
        {
            Response response;
            if (useUploadEndpoint)
            {
                response = upload.send(
                    method,
                    path,
                    query,
                    content,
                    contentType,
                    headers,
                );
            }
            else
            {
                response = api.send(
                    method,
                    path,
                    query,
                    content,
                    contentType,
                    headers,
                );
            }

            if (response.status == 401 && identity.tryRefresh())
            {
                headers["Authorization"] = "Bearer "~identity.tokens.accessToken;
                continue;
            }

            if (response.status >= 200 && response.status < 300)
                return response;

            Exception err = cast(Exception)mapError(response);
            if ((response.status == 429 || response.status >= 500) && attempt + 1 < 5)
            {
                Thread.sleep(dur!"msecs"(500 * (1 << attempt)));
                continue;
            }

            throw err;
        }

        throw new GDriveProtocolError("Google Drive request failed before completion.");
    }

    string filePath(string id) const
    {
        return "/drive/v3/files/"~encodeComponent(id);
    }

private:
    Throwable mapError(Response response)
    {
        JSONValue json = response.content == null ? JSONValue.init : parseJSON(cast(string)response.content);
        string message = "message" in json ? json["message"].str : null;
        if (message == null && "error" in json && json["error"].type == JSONType.object)
            message = "message" in json["error"] ? json["error"]["message"].str : null;

        if (message == null)
            message = "HTTP request failed with status "~response.status.to!string;

        if (response.status == 401)
            return new GDriveAuthError(message);

        if (response.status == 403)
            return new GDrivePermissionError(message);

        if (response.status == 404)
            return new GDriveNotFoundError(message);

        if (response.status == 429)
            return new GDriveRateLimitError(message);

        return new GDriveProtocolError(message);
    }

    void ensureAuthorized(Identity identity)
    {
        if (identity is null || identity.tokens.empty())
            throw new GDriveAuthError("No Google Drive session is available. Call `login()` first.");

        if (identity.tokens.expired() && !identity.tryRefresh())
            throw new GDriveAuthError("The Google Drive session has expired and could not be refreshed.");
    }

    string buildListQuery(string parentId, bool foldersOnly) const
    {
        string escapedParent = parentId.replace("'", "\\'");
        string ret = "'"~escapedParent~"' in parents";
        if (foldersOnly)
            ret ~= " and mimeType='"~folderMimeType~"'";
        else
            ret ~= " and mimeType!='"~folderMimeType~"'";

        return ret;
    }
}

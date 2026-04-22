module gdrive.test.dummy.integration;

version (GDriveTestDummy)
{
    import core.thread : Thread;
    import core.time : dur;
    import gdrive : File, Folder, folderMimeType, GDriveNotFoundError,
        Identity,
        GDrivePermissionError, GDriveUnsupportedContentError, Session;
    import conductor.http : send;
    import conductor.oauth : OAuth, TokenCache;
    import conductor.query : buildURL, parseQuery;
    import gdrive.test.dummy.testserver : SimpleHttpServer, TestRequest, TestResponse;
    import std.conv : to;
    import std.exception : assertThrown;
    import std.file : exists, read, remove, rmdirRecurse, tempDir;
    import std.json : JSONType, JSONValue, parseJSON;
    import std.net.curl : HTTP;
    import std.path : buildPath;
    import std.process : thisProcessID;
    import std.string : indexOf, lastIndexOf, startsWith;

    public:

    struct FakeEntry
    {
        string id;
        string name;
        string mimeType;
        string parentId;
        string modifiedTime = "2026-04-14T12:00:00Z";
        string webViewLink;
        string md5Checksum = "checksum";
        ubyte[] data;
        bool trashed;
        bool failDownload401Once;
        bool failUploadOnce;
    }

    struct FakeAuthStats
    {
        int launchCalls;
        int authorizationTokenCalls;
        int refreshCalls;
        int revokeCalls;
        Thread[] threads;
    }

    OAuth makeDummyOAuth(string baseUrl, FakeAuthStats* stats, TokenCache cache = null)
    {
        return new OAuth(
            "dummy-client-id",
            "dummy-client-secret",
            baseUrl~"/oauth/authorize",
            baseUrl~"/oauth/token",
            baseUrl~"/oauth/revoke",
            delegate void(string url) {
                stats.launchCalls++;

                ptrdiff_t question = url.indexOf('?');
                string[string] query = question < 0 ? string[string].init : parseQuery(url[question + 1..$]);
                string redirectUri = query.get("redirect_uri", null);
                string state = query.get("state", null);

                Thread thread = new Thread(() {
                    Thread.sleep(dur!"msecs"(50));
                    HTTP http = HTTP();
                    send(
                        http,
                        HTTP.Method.get,
                        buildURL(redirectUri, null, ["code": "dummy-code", "state": state]),
                    );
                });
                thread.start();
                stats.threads ~= thread;
            },
            null,
            null,
            null,
            null,
            dur!"minutes"(5),
            cache,
        );
    }

    class FakeDriveService
    {
        int aboutCalls;
        int rootListFailuresRemaining = 1;
        int createCalls;
        int updateCalls;
        int deleteCalls;
        bool omitAuthorizationScope;

        FakeAuthStats* stats;

        private int _nextId = 1;
        private FakeEntry[string] _entries;

        this(FakeAuthStats* stats)
        {
            this.stats = stats;

            addEntry(FakeEntry("folder-1", "Coursework", folderMimeType, "root"));

            FakeEntry file = FakeEntry("file-1", "Essay.pdf", "application/pdf", "folder-1");
            file.data = cast(ubyte[])"initial-data".dup;
            file.failDownload401Once = true;
            addEntry(file);

            FakeEntry stale = FakeEntry("stale-1", "Stale.txt", "text/plain", "folder-1");
            stale.data = cast(ubyte[])"stale-data".dup;
            stale.failUploadOnce = true;
            addEntry(stale);

            addEntry(FakeEntry("doc-1", "Doc", "application/vnd.google-apps.document", "folder-1"));
        }

        void addEntry(FakeEntry entry)
        {
            entry.webViewLink = "https://example.test/view/"~entry.id;
            if (entry.data == null)
                entry.data = null;

            _entries[entry.id] = entry;
        }

        bool hasEntry(string id)
        {
            return (id in _entries) !is null;
        }

        ubyte[] dataFor(string id)
        {
            FakeEntry* entry = id in _entries;
            if (entry !is null)
                return entry.data.dup;

            return null;
        }

        TestResponse handle(TestRequest request)
        {
            if (request.path == "/oauth/token" && request.method == "POST")
                return handleToken(request);
            if (request.path == "/oauth/revoke" && request.method == "POST")
                return handleRevoke(request);
            if (request.path == "/drive/v3/about")
                return handleAbout();

            if (request.path == "/drive/v3/files")
            {
                if (request.method == "GET")
                    return handleList(request);
                if (request.method == "POST")
                    return handleCreate(request);
            }

            if (request.path.startsWith("/drive/v3/files/"))
                return handleItem(request);

            if (request.path.startsWith("/upload/drive/v3/files/"))
                return handleUpload(request);

            return errorResponse(404, "Not Found", "notFound");
        }

    private:

        TestResponse handleToken(TestRequest request)
        {
            string[string] fields = parseQuery(cast(string)request.content);
            string grantType = fields.get("grant_type", null);

            JSONValue payload = JSONValue([
                "token_type": JSONValue("Bearer"),
                "expires_in": JSONValue(3600L),
            ]);
            if (!omitAuthorizationScope || grantType != "authorization_code")
                payload["scope"] = JSONValue("https://www.googleapis.com/auth/drive");

            if (grantType == "authorization_code")
            {
                stats.authorizationTokenCalls++;
                payload["access_token"] = JSONValue("access-1");
                payload["refresh_token"] = JSONValue("refresh-1");
                return jsonResponse(payload);
            }

            if (grantType == "refresh_token")
            {
                stats.refreshCalls++;
                payload["access_token"] = JSONValue("access-2");
                return jsonResponse(payload);
            }

            return errorResponse(400, "Bad Request", "unsupportedGrantType");
        }

        TestResponse handleRevoke(TestRequest request)
        {
            string[string] fields = parseQuery(cast(string)request.content);
            if (fields.get("token", null) != null)
                stats.revokeCalls++;

            TestResponse response;
            response.status = 200;
            response.reason = "OK";
            return response;
        }

        TestResponse handleAbout()
        {
            aboutCalls++;
            return jsonResponse(JSONValue([
                "user": JSONValue([
                    "displayName": JSONValue("Test User"),
                    "emailAddress": JSONValue("test@example.com"),
                    "permissionId": JSONValue("perm-1"),
                ]),
            ]));
        }

        TestResponse handleList(TestRequest request)
        {
            string[string] queryValues = parseQuery(request.queryString);
            string query = queryValues.get("q", null);
            string parentId = extractParentId(query);
            bool foldersOnly = query.indexOf("mimeType='"~folderMimeType~"'") >= 0;
            bool filesOnly = query.indexOf("mimeType!='"~folderMimeType~"'") >= 0;
            if (parentId == "root" && foldersOnly && rootListFailuresRemaining > 0)
            {
                rootListFailuresRemaining--;
                return errorResponse(503, "Service Unavailable", "backendError");
            }

            JSONValue items = JSONValue.emptyArray;
            foreach (FakeEntry entry; _entries.byValue)
            {
                if (entry.parentId != parentId)
                    continue;
                if (foldersOnly && entry.mimeType != folderMimeType)
                    continue;
                if (filesOnly && entry.mimeType == folderMimeType)
                    continue;
                items.array ~= metadataValue(entry);
            }

            return jsonResponse(JSONValue([
                "files": items,
            ]));
        }

        TestResponse handleCreate(TestRequest request)
        {
            JSONValue json = parseJSON(cast(string)request.content);
            string id = "created-"~(_nextId++).to!string;
            FakeEntry entry;
            entry.id = id;
            if ("name" in json && json["name"].type == JSONType.string)
                entry.name = json["name"].str;

            if ("mimeType" in json && json["mimeType"].type == JSONType.string)
                entry.mimeType = json["mimeType"].str;

            if ("parents" in json)
            {
                JSONValue parents = json["parents"];
                if (parents.type == JSONType.array && parents.array.length > 0 && parents.array[0].type == JSONType.string)
                    entry.parentId = parents.array[0].str;
            }
            if (entry.parentId == null)
                entry.parentId = "root";

            entry.webViewLink = "https://example.test/view/"~id;
            createCalls++;
            _entries[id] = entry;
            return jsonResponse(metadataValue(entry));
        }

        TestResponse handleItem(TestRequest request)
        {
            string id = request.path["/drive/v3/files/".length..$];

            if (id == "forbidden")
                return errorResponse(403, "Forbidden", "insufficientFilePermissions");

            if (request.method == "DELETE")
            {
                if (!hasEntry(id))
                    return errorResponse(404, "Not Found", "notFound");
                deleteCalls++;
                deleteRecursive(id);
                TestResponse response;
                response.status = 204;
                response.reason = "No Content";
                return response;
            }

            FakeEntry* entry = id in _entries;
            if (entry is null)
                return errorResponse(404, "Not Found", "notFound");

            string[string] queryValues = parseQuery(request.queryString);
            if (queryValues.get("alt", null) == "media")
            {
                string auth = headerValue(request, "authorization");
                if (entry.failDownload401Once && auth == "Bearer access-1")
                {
                    entry.failDownload401Once = false;
                    return errorResponse(401, "Unauthorized", "authError");
                }

                TestResponse response;
                response.headers["content-type"] = entry.mimeType;
                response.content = entry.data.dup;
                return response;
            }

            return jsonResponse(metadataValue(*entry));
        }

        TestResponse handleUpload(TestRequest request)
        {
            string id = request.path["/upload/drive/v3/files/".length..$];
            FakeEntry* entry = id in _entries;
            if (entry is null)
                return errorResponse(404, "Not Found", "notFound");

            if (entry.failUploadOnce)
            {
                entry.failUploadOnce = false;
                _entries.remove(id);
                return errorResponse(404, "Not Found", "notFound");
            }

            entry.data = extractMultipartData(request.content);
            entry.modifiedTime = "2026-04-14T12:05:00Z";
            updateCalls++;
            return jsonResponse(metadataValue(*entry));
        }

        void deleteRecursive(string id)
        {
            string[] children;
            foreach (string childId, FakeEntry entry; _entries)
            {
                if (entry.parentId == id)
                    children ~= childId;
            }

            foreach (string childId; children)
                deleteRecursive(childId);

            _entries.remove(id);
        }

        JSONValue metadataValue(FakeEntry entry)
        {
            return JSONValue([
                "id": JSONValue(entry.id),
                "name": JSONValue(entry.name),
                "mimeType": JSONValue(entry.mimeType),
                "parents": JSONValue([JSONValue(entry.parentId)]),
                "size": JSONValue(entry.data.length.to!string),
                "modifiedTime": JSONValue(entry.modifiedTime),
                "trashed": JSONValue(entry.trashed),
                "driveId": JSONValue("drive-1"),
                "webViewLink": JSONValue(entry.webViewLink),
                "md5Checksum": JSONValue(entry.md5Checksum),
            ]);
        }

        TestResponse jsonResponse(JSONValue payload)
        {
            TestResponse response;
            response.headers["content-type"] = "application/json";
            response.content = cast(ubyte[])payload.toString().dup;
            return response;
        }

        TestResponse errorResponse(ushort status, string reason, string apiReason)
        {
            TestResponse response = jsonResponse(JSONValue([
                "error": JSONValue([
                    "message": JSONValue(reason),
                    "errors": JSONValue([JSONValue(["reason": JSONValue(apiReason)])]),
                ]),
            ]));
            response.status = status;
            response.reason = reason;
            return response;
        }

        string headerValue(TestRequest request, string key)
        {
            const(string)* value = key in request.headers;
            if (value !is null)
                return *value;

            return null;
        }

        string extractParentId(string query)
        {
            ptrdiff_t start = query.indexOf('\'');
            if (start < 0)
                return null;

            ptrdiff_t finish = query[start + 1..$].indexOf('\'');
            if (finish < 0)
                return null;

            return query[start + 1..start + 1 + finish];
        }

        ubyte[] extractMultipartData(const(ubyte)[] content)
        {
            string text = cast(string)content;
            ptrdiff_t first = text.indexOf("\r\n\r\n");
            ptrdiff_t second = first < 0 ? -1 : text.indexOf("\r\n\r\n", first + 4);
            if (second < 0)
                return null;

            ptrdiff_t start = second + 4;
            ptrdiff_t end = text.lastIndexOf("\r\n--");
            if (end < start)
                end = text.length;

            return cast(ubyte[])text[start..end].dup;
        }
    }

    @system unittest
    {
        FakeAuthStats stats = FakeAuthStats.init;
        FakeDriveService service = new FakeDriveService(&stats);
        SimpleHttpServer server = new SimpleHttpServer((TestRequest request) => service.handle(request));
        scope (exit) server.close();
        string cacheDirectory = buildPath(
            tempDir(),
            "conductor-oauth-dummy-cache-"~thisProcessID.to!string~"-primary",
        );
        scope (exit)
        {
            if (exists(cacheDirectory))
                rmdirRecurse(cacheDirectory);
        }

        Session session = new Session(
            "GDrive Dummy Tests",
            makeDummyOAuth(server.baseUrl(), &stats, new TokenCache(cacheDirectory)),
            server.baseUrl(),
            server.baseUrl()~"/upload",
        );
        Identity identity = session.login();
        foreach (Thread thread; stats.threads)
            thread.join();
        stats.threads = null;

        assert(stats.launchCalls == 1);
        assert(stats.authorizationTokenCalls == 1);
        assert(identity.permissionId == "perm-1");
        assert(identity.email == "test@example.com");

        Folder[] roots = identity.folders();
        assert(roots.length == 1);
        assert(roots[0].name == "Coursework");

        File[] rootFiles = roots[0].files();
        assert(rootFiles.length == 3);
        assert(identity.file("file-1").read() == cast(ubyte[])"initial-data");
        assert(stats.refreshCalls == 1);

        Folder createdFolder = identity.create(new Folder(identity, "Draft Root"));
        assert(createdFolder.id != null);

        File createdFile = roots[0].create(new File(identity, "Created.txt", "text/plain"));
        createdFile.write(cast(const(ubyte)[])"created-data".dup);
        assert(service.dataFor(createdFile.id) == cast(ubyte[])"created-data");

        File draftFile = new File(
            identity,
            "Auto.txt",
            "text/plain",
            roots[0].id,
        );
        assert(draftFile.read() is null);
        draftFile.write(cast(const(ubyte)[])"auto-created".dup);
        assert(draftFile.id != null);
        assert(service.dataFor(draftFile.id) == cast(ubyte[])"auto-created");

        File staleFile = identity.file("stale-1");
        staleFile.write(cast(const(ubyte)[])"reborn-data".dup);
        assert(staleFile.id != "stale-1");
        assert(service.dataFor(staleFile.id) == cast(ubyte[])"reborn-data");
        assert(!service.hasEntry("stale-1"));

        File doomed = roots[0].create(new File(identity, "To Delete.txt", "text/plain"));
        doomed.write(cast(const(ubyte)[])"temporary".dup);
        identity.remove(doomed);
        assert(doomed.read() is null);

        string savePath = buildPath(tempDir(), "gdrive-dummy-save-"~thisProcessID.to!string);
        scope (exit)
        {
            if (exists(savePath))
                remove(savePath);
        }
        createdFile.save(savePath);
        assert(read(savePath) == cast(ubyte[])"created-data");

        File workspace = identity.file("doc-1");
        assertThrown!GDriveUnsupportedContentError(workspace.read());
        assertThrown!GDriveNotFoundError(identity.file("missing"));
        assertThrown!GDrivePermissionError(identity.file("forbidden"));

        identity.logout();

        assert(stats.revokeCalls == 1);
        assert(service.createCalls >= 3);
        assert(service.updateCalls >= 4);
        assert(service.deleteCalls == 1);
    }

    @system unittest
    {
        FakeAuthStats stats = FakeAuthStats.init;
        FakeDriveService service = new FakeDriveService(&stats);
        service.omitAuthorizationScope = true;

        SimpleHttpServer server = new SimpleHttpServer((TestRequest request) => service.handle(request));
        scope (exit) server.close();

        string cacheDirectory = buildPath(
            tempDir(),
            "conductor-oauth-dummy-cache-"~thisProcessID.to!string~"-scope",
        );
        scope (exit)
        {
            if (exists(cacheDirectory))
                rmdirRecurse(cacheDirectory);
        }

        Session session = new Session(
            "GDrive Dummy Cache Scope Tests",
            makeDummyOAuth(server.baseUrl(), &stats, new TokenCache(cacheDirectory)),
            server.baseUrl(),
            server.baseUrl()~"/upload",
        );

        Identity first = session.login();
        foreach (Thread thread; stats.threads)
            thread.join();
        stats.threads = null;
        assert(first.email == "test@example.com");

        Identity second = session.login();
        assert(second.email == "test@example.com");
        assert(stats.launchCalls == 1);
        assert(stats.authorizationTokenCalls == 1);

        first.logout();
        assert(stats.revokeCalls == 1);
    }

}

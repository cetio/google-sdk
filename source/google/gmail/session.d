module google.gmail.session;

import conductor.http : Response;
import conductor.oauth : OAuth, OAuthError, TokenBundle;
import conductor.orchestrate : Orchestrator;
import core.thread : Thread;
import core.time : dur;
import google.gmail.error;
import google.gmail.identity : Identity;
import google.gmail.label : Label;
import std.array : join;
import std.conv : to;
import std.json : JSONType, JSONValue, parseJSON;
import std.net.curl : HTTP;
import std.uri : encodeComponent;

class Session
{
private:
    enum defaultScope = "https://www.googleapis.com/auth/gmail.modify";

public:
    Orchestrator api;
    OAuth oauth;
    string name;

    this(
        string name,
        OAuth oauth,
        string apiUrl = "https://gmail.googleapis.com",
    )
    {
        this.name = name == null ? "GoogleSDK" : name;
        this.oauth = oauth;
        this.api = Orchestrator(apiUrl);
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
            throw new GmailAuthError(err.msg);

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
            throw new GmailAuthError(err.msg);

        identity.tokens = TokenBundle.init;
    }

    JSONValue[] listMessages(
        Identity identity,
        string query = null,
        string[] labelIds = null,
        string maxResults = "100",
    )
    {
        JSONValue[] ret;
        string pageToken;

        do
        {
            string[string] params;
            params["maxResults"] = maxResults;
            if (query != null)
                params["q"] = query;
            if (labelIds != null && labelIds.length)
                params["labelIds"] = encodeComponent(labelIds.join(","));
            if (pageToken != null)
                params["pageToken"] = pageToken;

            JSONValue json = requestJson(
                identity,
                HTTP.Method.get,
                "/gmail/v1/users/me/messages",
                params,
            );

            if ("messages" in json && json["messages"].type == JSONType.array)
            {
                foreach (JSONValue item; json["messages"].array)
                    ret ~= item;
            }

            pageToken = "nextPageToken" in json ? json["nextPageToken"].str : null;
        }
        while (pageToken != null);

        return ret;
    }

    JSONValue getMessage(Identity identity, string id, string format = "full")
    {
        return requestJson(
            identity,
            HTTP.Method.get,
            "/gmail/v1/users/me/messages/"~encodeComponent(id),
            ["format": format],
        );
    }

    JSONValue sendMessage(Identity identity, string raw)
    {
        JSONValue payload = JSONValue.emptyObject;
        payload["raw"] = JSONValue(raw);

        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/messages/send",
            null,
            cast(const(ubyte)[])payload.toString().dup,
            "application/json; charset=UTF-8",
        );
    }

    JSONValue trashMessage(Identity identity, string id)
    {
        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/messages/"~encodeComponent(id)~"/trash",
        );
    }

    JSONValue untrashMessage(Identity identity, string id)
    {
        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/messages/"~encodeComponent(id)~"/untrash",
        );
    }

    void deleteMessage(Identity identity, string id)
    {
        execute(
            identity,
            HTTP.Method.del,
            "/gmail/v1/users/me/messages/"~encodeComponent(id),
        );
    }

    JSONValue modifyMessage(
        Identity identity,
        string id,
        string[] addLabelIds = null,
        string[] removeLabelIds = null,
    )
    {
        JSONValue payload = JSONValue.emptyObject;
        payload["addLabelIds"] = labelArray(addLabelIds);
        payload["removeLabelIds"] = labelArray(removeLabelIds);

        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/messages/"~encodeComponent(id)~"/modify",
            null,
            cast(const(ubyte)[])payload.toString().dup,
            "application/json; charset=UTF-8",
        );
    }

    JSONValue[] listThreads(
        Identity identity,
        string query = null,
        string[] labelIds = null,
        string maxResults = "100",
    )
    {
        JSONValue[] ret;
        string pageToken;

        do
        {
            string[string] params;
            params["maxResults"] = maxResults;
            if (query != null)
                params["q"] = query;
            if (labelIds != null && labelIds.length)
                params["labelIds"] = encodeComponent(labelIds.join(","));
            if (pageToken != null)
                params["pageToken"] = pageToken;

            JSONValue json = requestJson(
                identity,
                HTTP.Method.get,
                "/gmail/v1/users/me/threads",
                params,
            );

            if ("threads" in json && json["threads"].type == JSONType.array)
            {
                foreach (JSONValue item; json["threads"].array)
                    ret ~= item;
            }

            pageToken = "nextPageToken" in json ? json["nextPageToken"].str : null;
        }
        while (pageToken != null);

        return ret;
    }

    JSONValue getThread(Identity identity, string id, string format = "full")
    {
        return requestJson(
            identity,
            HTTP.Method.get,
            "/gmail/v1/users/me/threads/"~encodeComponent(id),
            ["format": format],
        );
    }

    JSONValue trashThread(Identity identity, string id)
    {
        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/threads/"~encodeComponent(id)~"/trash",
        );
    }

    JSONValue untrashThread(Identity identity, string id)
    {
        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/threads/"~encodeComponent(id)~"/untrash",
        );
    }

    void deleteThread(Identity identity, string id)
    {
        execute(
            identity,
            HTTP.Method.del,
            "/gmail/v1/users/me/threads/"~encodeComponent(id),
        );
    }

    JSONValue modifyThread(
        Identity identity,
        string id,
        string[] addLabelIds = null,
        string[] removeLabelIds = null,
    )
    {
        JSONValue payload = JSONValue.emptyObject;
        payload["addLabelIds"] = labelArray(addLabelIds);
        payload["removeLabelIds"] = labelArray(removeLabelIds);

        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/threads/"~encodeComponent(id)~"/modify",
            null,
            cast(const(ubyte)[])payload.toString().dup,
            "application/json; charset=UTF-8",
        );
    }

    JSONValue[] listLabels(Identity identity)
    {
        JSONValue[] ret;
        JSONValue json = requestJson(
            identity,
            HTTP.Method.get,
            "/gmail/v1/users/me/labels",
        );

        if ("labels" in json && json["labels"].type == JSONType.array)
        {
            foreach (JSONValue item; json["labels"].array)
                ret ~= item;
        }

        return ret;
    }

    JSONValue getLabel(Identity identity, string id)
    {
        return requestJson(
            identity,
            HTTP.Method.get,
            "/gmail/v1/users/me/labels/"~encodeComponent(id),
        );
    }

    JSONValue createLabel(Identity identity, Label label)
    {
        return requestJson(
            identity,
            HTTP.Method.post,
            "/gmail/v1/users/me/labels",
            null,
            cast(const(ubyte)[])label.toJson().toString().dup,
            "application/json; charset=UTF-8",
        );
    }

    JSONValue updateLabel(Identity identity, Label label)
    {
        return requestJson(
            identity,
            HTTP.Method.put,
            "/gmail/v1/users/me/labels/"~encodeComponent(label.id),
            null,
            cast(const(ubyte)[])label.toJson().toString().dup,
            "application/json; charset=UTF-8",
        );
    }

    void deleteLabel(Identity identity, string id)
    {
        execute(
            identity,
            HTTP.Method.del,
            "/gmail/v1/users/me/labels/"~encodeComponent(id),
        );
    }

    JSONValue requestJson(
        Identity identity,
        HTTP.Method method,
        string path,
        string[string] query = null,
        const(ubyte)[] content = null,
        string contentType = null,
    )
    {
        Response response = execute(
            identity,
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
            Response response = api.send(
                method,
                path,
                query,
                content,
                contentType,
                headers,
            );

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

        throw new GmailProtocolError("Gmail request failed before completion.");
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
            return new GmailAuthError(message);

        if (response.status == 403)
            return new GmailPermissionError(message);

        if (response.status == 404)
            return new GmailNotFoundError(message);

        if (response.status == 429)
            return new GmailRateLimitError(message);

        return new GmailProtocolError(message);
    }

    void ensureAuthorized(Identity identity)
    {
        if (identity is null || identity.tokens.empty())
            throw new GmailAuthError("No Gmail session is available. Call `login()` first.");

        if (identity.tokens.expired() && !identity.tryRefresh())
            throw new GmailAuthError("The Gmail session has expired and could not be refreshed.");
    }

    JSONValue labelArray(string[] labelIds)
    {
        JSONValue ret = JSONValue.emptyArray;

        if (labelIds != null)
        {
            foreach (string labelId; labelIds)
                ret.array ~= JSONValue(labelId);
        }

        return ret;
    }
}

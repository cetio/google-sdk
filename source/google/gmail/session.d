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


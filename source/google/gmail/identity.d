module google.gmail.identity;

import conductor.oauth : OAuthError, TokenBundle;
import google.gmail.exception : GmailAuthException, GmailNotFoundException, GmailProtocolException;
import google.gmail.label : Label;
import google.gmail.message : Message;
import google.gmail.session : Session;
import google.gmail.thread : Thread;
import std.json : JSONType, JSONValue;
import std.net.curl : HTTP;

class Identity
{
public:
    Session session;
    TokenBundle tokens;
    string requestedScope;
    string email;
    string displayName;
    long messagesTotal;
    long threadsTotal;
    string historyId;

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

    Message[] messages(string query = null, string[] labelIds = null)
    {
        Message[] ret;
        foreach (JSONValue item; session.listMessages(this, query, labelIds))
            ret ~= Message.fromJson(item);

        return ret;
    }

    Message message(string id)
    {
        JSONValue value = session.getMessage(this, id);
        if (value.type == JSONType.null_)
            throw new GmailNotFoundException("Gmail message does not exist.");

        return Message.fromJson(value);
    }

    Message send(string raw)
    {
        JSONValue value = session.sendMessage(this, raw);
        return Message.fromJson(value);
    }

    Message trash(Message msg)
    {
        if (msg is null || msg.id == null)
            return msg;

        JSONValue value = session.trashMessage(this, msg.id);
        msg.apply(value);
        return msg;
    }

    Message untrash(Message msg)
    {
        if (msg is null || msg.id == null)
            return msg;

        JSONValue value = session.untrashMessage(this, msg.id);
        msg.apply(value);
        return msg;
    }

    void remove(Message msg)
    {
        if (msg is null || msg.id == null)
            return;

        session.deleteMessage(this, msg.id);
        msg.id = null;
    }

    Message modifyLabels(Message msg, string[] add = null, string[] remove = null)
    {
        if (msg is null || msg.id == null)
            throw new GmailProtocolException("Cannot modify labels of a null or unsent message.");

        JSONValue value = session.modifyMessage(this, msg.id, add, remove);
        msg.apply(value);
        return msg;
    }

    Thread[] threads(string query = null, string[] labelIds = null)
    {
        Thread[] ret;
        foreach (JSONValue item; session.listThreads(this, query, labelIds))
            ret ~= Thread.fromJson(item);

        return ret;
    }

    Thread thread(string id)
    {
        JSONValue value = session.getThread(this, id);
        if (value.type == JSONType.null_)
            throw new GmailNotFoundException("Gmail thread does not exist.");

        return Thread.fromJson(value);
    }

    Thread trashThread(Thread thread)
    {
        if (thread is null || thread.id == null)
            return thread;

        JSONValue value = session.trashThread(this, thread.id);
        thread.apply(value);
        return thread;
    }

    Thread untrashThread(Thread thread)
    {
        if (thread is null || thread.id == null)
            return thread;

        JSONValue value = session.untrashThread(this, thread.id);
        thread.apply(value);
        return thread;
    }

    void removeThread(Thread thread)
    {
        if (thread is null || thread.id == null)
            return;

        session.deleteThread(this, thread.id);
        thread.id = null;
    }

    Thread modifyThreadLabels(Thread thread, string[] add = null, string[] remove = null)
    {
        if (thread is null || thread.id == null)
            throw new GmailProtocolException("Cannot modify labels of a null or unsaved thread.");

        JSONValue value = session.modifyThread(this, thread.id, add, remove);
        thread.apply(value);
        return thread;
    }

    Label[] labels()
    {
        Label[] ret;
        foreach (JSONValue item; session.listLabels(this))
            ret ~= Label.fromJson(item);

        return ret;
    }

    Label label(string id)
    {
        JSONValue value = session.getLabel(this, id);
        if (value.type == JSONType.null_)
            throw new GmailNotFoundException("Gmail label does not exist.");

        return Label.fromJson(value);
    }

    Label create(Label label)
    {
        if (label is null)
            throw new GmailProtocolException("Cannot create a null Gmail label.");

        JSONValue value = session.createLabel(this, label);
        label.apply(value);
        return label;
    }

    Label update(Label label)
    {
        if (label is null || label.id == null)
            throw new GmailProtocolException("Cannot update a null or unsaved Gmail label.");

        JSONValue value = session.updateLabel(this, label);
        label.apply(value);
        return label;
    }

    void remove(Label label)
    {
        if (label is null || label.id == null)
            return;

        session.deleteLabel(this, label.id);
        label.id = null;
    }

    void refresh()
    {
        JSONValue json = session.requestJson(
            this,
            HTTP.Method.get,
            "/gmail/v1/users/me/profile",
        );

        email = "emailAddress" in json ? json["emailAddress"].str : null;
        messagesTotal = parseLong(json, "messagesTotal");
        threadsTotal = parseLong(json, "threadsTotal");
        historyId = "historyId" in json ? json["historyId"].str : null;
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
        catch (OAuthError ex)
            throw new GmailAuthException(ex.msg);

        return true;
    }

private:
    static long parseLong(JSONValue value, string field)
    {
        if (field in value)
        {
            switch (value[field].type)
            {
            case JSONType.uinteger:
                return value[field].uinteger;

            case JSONType.integer:
                return value[field].integer;

            default:
                return 0;
            }
        }

        return 0;
    }
}

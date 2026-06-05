module google.gmail.message;

import std.json : JSONType, JSONValue;

public:

struct Header
{
    string name;
    string value;

    static Header fromJson(JSONValue value)
    {
        Header ret;
        ret.name = "name" in value ? value["name"].str : null;
        ret.value = "value" in value ? value["value"].str : null;
        return ret;
    }
}

struct MessagePartBody
{
    string data;
    long size;
    string attachmentId;

    static MessagePartBody fromJson(JSONValue value)
    {
        MessagePartBody ret;
        ret.data = "data" in value ? value["data"].str : null;

        if ("size" in value)
        {
            switch (value["size"].type)
            {
            case JSONType.uinteger:
                ret.size = value["size"].uinteger;
                break;

            case JSONType.integer:
                ret.size = value["size"].integer;
                break;

            default:
                ret.size = 0;
                break;
            }
        }

        ret.attachmentId = "attachmentId" in value ? value["attachmentId"].str : null;
        return ret;
    }
}

struct MessagePart
{
    string partId;
    string mimeType;
    string filename;
    Header[] headers;
    MessagePartBody body;
    MessagePart[] parts;

    static MessagePart fromJson(JSONValue value)
    {
        MessagePart ret;
        ret.partId = "partId" in value ? value["partId"].str : null;
        ret.mimeType = "mimeType" in value ? value["mimeType"].str : null;
        ret.filename = "filename" in value ? value["filename"].str : null;

        if ("headers" in value && value["headers"].type == JSONType.array)
        {
            foreach (JSONValue item; value["headers"].array)
                ret.headers ~= Header.fromJson(item);
        }

        if ("body" in value && value["body"].type == JSONType.object)
            ret.body = MessagePartBody.fromJson(value["body"]);

        if ("parts" in value && value["parts"].type == JSONType.array)
        {
            foreach (JSONValue item; value["parts"].array)
                ret.parts ~= MessagePart.fromJson(item);
        }

        return ret;
    }
}

class Message
{
public:
    string id() const
        => _id;

    string id(string value)
        => _id = value;

    string threadId() const
        => _threadId;

    string threadId(string value)
        => _threadId = value;

    string[] labelIds()
        => _labelIds;

    string[] labelIds(string[] value)
        => _labelIds = value;

    string snippet() const
        => _snippet;

    string snippet(string value)
        => _snippet = value;

    string historyId() const
        => _historyId;

    string historyId(string value)
        => _historyId = value;

    string internalDate() const
        => _internalDate;

    string internalDate(string value)
        => _internalDate = value;

    long sizeEstimate() const
        => _sizeEstimate;

    long sizeEstimate(long value)
        => _sizeEstimate = value;

    string raw() const
        => _raw;

    string raw(string value)
        => _raw = value;

    MessagePart payload()
        => _payload;

    MessagePart payload(MessagePart value)
        => _payload = value;

    static Message fromJson(JSONValue value)
    {
        Message ret = new Message();
        ret.apply(value);
        return ret;
    }

    void apply(JSONValue value)
    {
        _id = "id" in value ? value["id"].str : null;
        _threadId = "threadId" in value ? value["threadId"].str : null;

        if ("labelIds" in value && value["labelIds"].type == JSONType.array)
        {
            foreach (JSONValue item; value["labelIds"].array)
            {
                if (item.type == JSONType.string)
                    _labelIds ~= item.str;
            }
        }

        _snippet = "snippet" in value ? value["snippet"].str : null;
        _historyId = "historyId" in value ? value["historyId"].str : null;
        _internalDate = "internalDate" in value ? value["internalDate"].str : null;

        if ("sizeEstimate" in value)
        {
            switch (value["sizeEstimate"].type)
            {
            case JSONType.uinteger:
                _sizeEstimate = value["sizeEstimate"].uinteger;
                break;

            case JSONType.integer:
                _sizeEstimate = value["sizeEstimate"].integer;
                break;

            default:
                _sizeEstimate = 0;
                break;
            }
        }

        _raw = "raw" in value ? value["raw"].str : null;

        if ("payload" in value && value["payload"].type == JSONType.object)
            _payload = MessagePart.fromJson(value["payload"]);
    }

private:
    string _id;
    string _threadId;
    string[] _labelIds;
    string _snippet;
    string _historyId;
    string _internalDate;
    long _sizeEstimate;
    string _raw;
    MessagePart _payload;
}

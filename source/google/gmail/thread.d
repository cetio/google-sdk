module google.gmail.thread;

import google.gmail.message : Message;
import std.json : JSONType, JSONValue;

public:

class Thread
{
public:
    string id() const
        => _id;

    string id(string value)
        => _id = value;

    string snippet() const
        => _snippet;

    string snippet(string value)
        => _snippet = value;

    string historyId() const
        => _historyId;

    string historyId(string value)
        => _historyId = value;

    Message[] messages()
        => _messages;

    Message[] messages(Message[] value)
        => _messages = value;

    static Thread fromJson(JSONValue value)
    {
        Thread ret = new Thread();
        ret.apply(value);
        return ret;
    }

    void apply(JSONValue value)
    {
        _id = "id" in value ? value["id"].str : null;
        _snippet = "snippet" in value ? value["snippet"].str : null;
        _historyId = "historyId" in value ? value["historyId"].str : null;

        if ("messages" in value && value["messages"].type == JSONType.array)
        {
            foreach (JSONValue item; value["messages"].array)
                _messages ~= Message.fromJson(item);
        }
    }

private:
    string _id;
    string _snippet;
    string _historyId;
    Message[] _messages;
}

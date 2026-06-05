module google.gmail.label;

import std.json : JSONType, JSONValue;

public:

enum MessageListVisibility
{
    Show,
    Hide,
}

enum LabelListVisibility
{
    LabelShow,
    LabelShowIfUnread,
    LabelHide,
}

enum LabelType
{
    System,
    User,
}

struct LabelColor
{
    string textColor;
    string backgroundColor;

    static LabelColor fromJson(JSONValue value)
    {
        LabelColor ret;
        ret.textColor = "textColor" in value ? value["textColor"].str : null;
        ret.backgroundColor = "backgroundColor" in value ? value["backgroundColor"].str : null;
        return ret;
    }
}

class Label
{
public:
    string id() const
        => _id;

    string id(string value)
        => _id = value;

    string name() const
        => _name;

    string name(string value)
        => _name = value;

    MessageListVisibility messageListVisibility() const
        => _messageListVisibility;

    MessageListVisibility messageListVisibility(MessageListVisibility value)
        => _messageListVisibility = value;

    LabelListVisibility labelListVisibility() const
        => _labelListVisibility;

    LabelListVisibility labelListVisibility(LabelListVisibility value)
        => _labelListVisibility = value;

    LabelType type() const
        => _type;

    LabelType type(LabelType value)
        => _type = value;

    long messagesTotal() const
        => _messagesTotal;

    long messagesTotal(long value)
        => _messagesTotal = value;

    long messagesUnread() const
        => _messagesUnread;

    long messagesUnread(long value)
        => _messagesUnread = value;

    long threadsTotal() const
        => _threadsTotal;

    long threadsTotal(long value)
        => _threadsTotal = value;

    long threadsUnread() const
        => _threadsUnread;

    long threadsUnread(long value)
        => _threadsUnread = value;

    LabelColor color() const
        => _color;

    LabelColor color(LabelColor value)
        => _color = value;

    static Label fromJson(JSONValue value)
    {
        Label ret = new Label();
        ret.apply(value);
        return ret;
    }

    void apply(JSONValue value)
    {
        _id = "id" in value ? value["id"].str : null;
        _name = "name" in value ? value["name"].str : null;
        _messageListVisibility = parseMessageListVisibility(value);
        _labelListVisibility = parseLabelListVisibility(value);
        _type = parseLabelType(value);
        _messagesTotal = parseLong(value, "messagesTotal");
        _messagesUnread = parseLong(value, "messagesUnread");
        _threadsTotal = parseLong(value, "threadsTotal");
        _threadsUnread = parseLong(value, "threadsUnread");

        if ("color" in value && value["color"].type == JSONType.object)
            _color = LabelColor.fromJson(value["color"]);
    }

    JSONValue toJson() const
    {
        JSONValue ret = JSONValue.emptyObject;
        ret["id"] = JSONValue(_id);
        ret["name"] = JSONValue(_name);
        ret["messageListVisibility"] = JSONValue(messageListVisibilityString());
        ret["labelListVisibility"] = JSONValue(labelListVisibilityString());

        if (_color.textColor != null || _color.backgroundColor != null)
        {
            JSONValue colorObj = JSONValue.emptyObject;
            colorObj["textColor"] = JSONValue(_color.textColor);
            colorObj["backgroundColor"] = JSONValue(_color.backgroundColor);
            ret["color"] = colorObj;
        }

        return ret;
    }

private:
    string _id;
    string _name;
    MessageListVisibility _messageListVisibility = MessageListVisibility.Show;
    LabelListVisibility _labelListVisibility = LabelListVisibility.LabelShow;
    LabelType _type = LabelType.User;
    long _messagesTotal;
    long _messagesUnread;
    long _threadsTotal;
    long _threadsUnread;
    LabelColor _color;

    static MessageListVisibility parseMessageListVisibility(JSONValue value)
    {
        if ("messageListVisibility" in value && value["messageListVisibility"].type == JSONType.string)
        {
            switch (value["messageListVisibility"].str)
            {
            case "hide":
                return MessageListVisibility.Hide;

            case "show":
            default:
                return MessageListVisibility.Show;
            }
        }

        return MessageListVisibility.Show;
    }

    static LabelListVisibility parseLabelListVisibility(JSONValue value)
    {
        if ("labelListVisibility" in value && value["labelListVisibility"].type == JSONType.string)
        {
            switch (value["labelListVisibility"].str)
            {
            case "labelShowIfUnread":
                return LabelListVisibility.LabelShowIfUnread;

            case "labelHide":
                return LabelListVisibility.LabelHide;

            case "labelShow":
            default:
                return LabelListVisibility.LabelShow;
            }
        }

        return LabelListVisibility.LabelShow;
    }

    static LabelType parseLabelType(JSONValue value)
    {
        if ("type" in value && value["type"].type == JSONType.string)
        {
            switch (value["type"].str)
            {
            case "system":
                return LabelType.System;

            case "user":
            default:
                return LabelType.User;
            }
        }

        return LabelType.User;
    }

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

    string messageListVisibilityString() const
    {
        switch (_messageListVisibility)
        {
        case MessageListVisibility.Hide:
            return "hide";

        case MessageListVisibility.Show:
        default:
            return "show";
        }
    }

    string labelListVisibilityString() const
    {
        switch (_labelListVisibility)
        {
        case LabelListVisibility.LabelShowIfUnread:
            return "labelShowIfUnread";

        case LabelListVisibility.LabelHide:
            return "labelHide";

        case LabelListVisibility.LabelShow:
        default:
            return "labelShow";
        }
    }
}

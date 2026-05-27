module google.sheets.cell;

import std.conv : to;

public:

enum CellType
{
    Empty,
    String,
    Integer,
    Floating,
    Boolean,
}

struct CellValue
{
    CellType type = CellType.Empty;
    string str;
    long integer;
    double floating;
    bool boolean;

    this(string value)
    {
        type = CellType.String;
        str = value;
    }

    this(long value)
    {
        type = CellType.Integer;
        integer = value;
    }

    this(double value)
    {
        type = CellType.Floating;
        floating = value;
    }

    this(bool value)
    {
        type = CellType.Boolean;
        boolean = value;
    }

    static CellValue empty()
    {
        CellValue ret;
        ret.type = CellType.Empty;
        return ret;
    }

    size_t toHash() const
    {
        size_t ret = cast(size_t)type;
        final switch (type)
        {
        case CellType.Empty:
            break;

        case CellType.String:
            foreach (char c; str)
                ret = ret * 31 + c;
            break;

        case CellType.Integer:
            ret = ret * 31 + cast(size_t)integer;
            break;

        case CellType.Floating:
            ret = ret * 31 + cast(size_t)(floating * 1_000_000);
            break;

        case CellType.Boolean:
            ret = ret * 31 + (boolean ? 1 : 0);
            break;
        }
        return ret;
    }

    bool opEquals(const CellValue rhs) const
    {
        if (type != rhs.type)
            return false;

        final switch (type)
        {
        case CellType.Empty:
            return true;

        case CellType.String:
            return str == rhs.str;

        case CellType.Integer:
            return integer == rhs.integer;

        case CellType.Floating:
            return floating == rhs.floating;

        case CellType.Boolean:
            return boolean == rhs.boolean;
        }
    }

    bool opEquals(string rhs) const
    {
        if (type != CellType.String)
            return false;

        return str == rhs;
    }

    bool opEquals(long rhs) const
    {
        if (type != CellType.Integer)
            return false;

        return integer == rhs;
    }

    bool opEquals(double rhs) const
    {
        if (type != CellType.Floating)
            return false;

        return floating == rhs;
    }

    bool opEquals(bool rhs) const
    {
        if (type != CellType.Boolean)
            return false;

        return boolean == rhs;
    }

    string toString() const
    {
        final switch (type)
        {
        case CellType.Empty:
            return "";

        case CellType.String:
            return str;

        case CellType.Integer:
            return integer.to!string;

        case CellType.Floating:
            return floating.to!string;

        case CellType.Boolean:
            return boolean.to!string;
        }
    }
}

package:

CellValue parseCell(string text)
{
    if (text == null || text.length == 0)
        return CellValue.empty;

    if (text == "true")
        return CellValue(true);

    if (text == "false")
        return CellValue(false);

    try
    {
        long ret = to!long(text);
        return CellValue(ret);
    }
    catch (Exception)
    {
    }

    try
    {
        double ret = to!double(text);
        return CellValue(ret);
    }
    catch (Exception)
    {
    }

    return CellValue(text);
}

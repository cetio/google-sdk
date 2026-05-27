module google.sheets.cell;

import std.conv : to;
import std.exception : enforce;

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
public:
    CellType type() const
        => _type;

    bool isEmpty() const
        => _type == CellType.Empty;

    bool isString() const
        => _type == CellType.String;

    bool isInteger() const
        => _type == CellType.Integer;

    bool isFloating() const
        => _type == CellType.Floating;

    bool isBoolean() const
        => _type == CellType.Boolean;

    string str() const
    {
        enforce(_type == CellType.String, "CellValue is not a string.");
        return _str;
    }

    long integer() const
    {
        enforce(_type == CellType.Integer, "CellValue is not an integer.");
        return _integer;
    }

    double floating() const
    {
        enforce(_type == CellType.Floating, "CellValue is not a floating point.");
        return _floating;
    }

    bool boolean() const
    {
        enforce(_type == CellType.Boolean, "CellValue is not a boolean.");
        return _boolean;
    }

    this(string value)
    {
        _type = CellType.String;
        _str = value;
    }

    this(long value)
    {
        _type = CellType.Integer;
        _integer = value;
    }

    this(double value)
    {
        _type = CellType.Floating;
        _floating = value;
    }

    this(bool value)
    {
        _type = CellType.Boolean;
        _boolean = value;
    }

    static CellValue empty()
    {
        CellValue ret;
        ret._type = CellType.Empty;
        return ret;
    }

    size_t toHash() const
    {
        size_t ret = cast(size_t)_type;
        final switch (_type)
        {
        case CellType.Empty:
            break;

        case CellType.String:
            foreach (char c; _str)
                ret = ret * 31 + c;
            break;

        case CellType.Integer:
            ret = ret * 31 + cast(size_t)_integer;
            break;

        case CellType.Floating:
            ret = ret * 31 + cast(size_t)(_floating * 1_000_000);
            break;

        case CellType.Boolean:
            ret = ret * 31 + (_boolean ? 1 : 0);
            break;
        }
        return ret;
    }

    bool opEquals(const CellValue rhs) const
    {
        if (_type != rhs._type)
            return false;

        final switch (_type)
        {
        case CellType.Empty:
            return true;

        case CellType.String:
            return _str == rhs._str;

        case CellType.Integer:
            return _integer == rhs._integer;

        case CellType.Floating:
            return _floating == rhs._floating;

        case CellType.Boolean:
            return _boolean == rhs._boolean;
        }
    }

    bool opEquals(string rhs) const
    {
        if (_type != CellType.String)
            return false;

        return _str == rhs;
    }

    bool opEquals(long rhs) const
    {
        if (_type != CellType.Integer)
            return false;

        return _integer == rhs;
    }

    bool opEquals(double rhs) const
    {
        if (_type != CellType.Floating)
            return false;

        return _floating == rhs;
    }

    bool opEquals(bool rhs) const
    {
        if (_type != CellType.Boolean)
            return false;

        return _boolean == rhs;
    }

    string toString() const
    {
        final switch (_type)
        {
        case CellType.Empty:
            return "";

        case CellType.String:
            return _str;

        case CellType.Integer:
            return _integer.to!string;

        case CellType.Floating:
            return _floating.to!string;

        case CellType.Boolean:
            return _boolean.to!string;
        }
    }

private:
    CellType _type = CellType.Empty;
    string _str;
    long _integer;
    double _floating;
    bool _boolean;
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
    catch (Exception) { }

    try
    {
        double ret = to!double(text);
        return CellValue(ret);
    }
    catch (Exception) { }

    return CellValue(text);
}

unittest
{
    CellValue empty = CellValue.empty;
    assert(empty.type == CellType.Empty);

    CellValue str = CellValue("hello");
    assert(str.type == CellType.String);
    assert(str.str == "hello");

    CellValue integer = CellValue(42L);
    assert(integer.type == CellType.Integer);
    assert(integer.integer == 42L);

    CellValue floating = CellValue(3.14);
    assert(floating.type == CellType.Floating);
    assert(floating.floating == 3.14);

    CellValue boolean = CellValue(true);
    assert(boolean.type == CellType.Boolean);
    assert(boolean.boolean == true);

    assert(parseCell("") == CellValue.empty);
    assert(parseCell("true") == true);
    assert(parseCell("false") == false);
    assert(parseCell("42") == 42L);
    assert(parseCell("3.14") == 3.14);
    assert(parseCell("hello") == "hello");
}

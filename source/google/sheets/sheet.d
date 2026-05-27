module google.sheets.sheet;

import google.drive.ifile : IFile;
import google.sheets.cell : CellValue, CellType, parseCell;
import google.sheets.row : Row;

public:

enum SheetType
{
    Snapshot,
    Live,
}

struct Slice(size_t dim)
{
    size_t start;
    size_t end;
}

struct Sheet
{
public:
    SheetType type() const
        => _type;

    IFile file() const
        => _file;

    size_t length() const
        => _data.length;

    size_t opDollar() const
        => _data.length;

    size_t opDollar(size_t dim)() const
    {
        static if (dim == 0)
            return _data.length;
        else static if (dim == 1)
        {
            if (_data.length == 0)
                return 0;

            size_t ret = _data[0].length;
            foreach (CellValue[] row; _data)
            {
                if (row.length > ret)
                    ret = row.length;
            }
            return ret;
        }
        else
            static assert(false, "Sheet only supports 2 dimensions.");
    }

    Row opIndex(size_t row) const
    {
        if (row >= _data.length)
            throw new Exception("Row index out of bounds.");

        return Row(_data[row]);
    }

    CellValue opIndex(size_t row, size_t col) const
    {
        if (row >= _data.length)
            throw new Exception("Row index out of bounds.");

        if (col >= _data[row].length)
            throw new Exception("Column index out of bounds.");

        return _data[row][col];
    }

    Slice!0 opSlice(size_t start, size_t end) const
    {
        return Slice!0(start, end);
    }

    Slice!dim opSlice(size_t dim)(size_t start, size_t end) const
    {
        return Slice!dim(start, end);
    }

    Sheet opIndex(Slice!0 rows) const
    {
        Sheet ret;
        ret._type = _type;
        ret._file = _file;

        foreach (size_t rowIndex; rows.start..rows.end)
        {
            if (rowIndex >= _data.length)
                throw new Exception("Row slice out of bounds.");

            ret._data ~= _data[rowIndex].dup;
        }

        return ret;
    }

    Sheet opIndex(Slice!0 rows, Slice!1 cols) const
    {
        Sheet ret;
        ret._type = _type;
        ret._file = _file;

        foreach (size_t rowIndex; rows.start..rows.end)
        {
            if (rowIndex >= _data.length)
                throw new Exception("Row slice out of bounds.");

            CellValue[] rowSlice;
            size_t actualEnd = cols.end;
            if (actualEnd > _data[rowIndex].length)
                actualEnd = _data[rowIndex].length;

            foreach (size_t colIndex; cols.start..actualEnd)
                rowSlice ~= _data[rowIndex][colIndex];

            ret._data ~= rowSlice;
        }

        return ret;
    }

    Row opIndex(size_t row, Slice!1 cols) const
    {
        if (row >= _data.length)
            throw new Exception("Row index out of bounds.");

        CellValue[] rowSlice;
        size_t actualEnd = cols.end;
        if (actualEnd > _data[row].length)
            actualEnd = _data[row].length;

        foreach (size_t colIndex; cols.start..actualEnd)
            rowSlice ~= _data[row][colIndex];

        return Row(rowSlice);
    }

    CellValue[] opIndex(Slice!0 rows, size_t col) const
    {
        CellValue[] ret;
        foreach (size_t rowIndex; rows.start..rows.end)
        {
            if (rowIndex >= _data.length)
                throw new Exception("Row slice out of bounds.");

            if (col >= _data[rowIndex].length)
                throw new Exception("Column index out of bounds.");

            ret ~= _data[rowIndex][col];
        }

        return ret;
    }

    static Sheet fromText(string csv, IFile file = null, SheetType type = SheetType.Snapshot)
    {
        Sheet ret;
        ret._type = type;
        ret._file = file;
        ret._data = parseCsv(csv);
        return ret;
    }

private:
    SheetType _type = SheetType.Snapshot;
    IFile _file;
    CellValue[][] _data;
}

package:

CellValue[][] parseCsv(string csv)
{
    CellValue[][] ret;
    if (csv == null || csv.length == 0)
        return ret;

    CellValue[] currentRow;
    string currentField;
    bool inQuotes = false;
    size_t i = 0;

    while (i < csv.length)
    {
        char c = csv[i];

        if (inQuotes)
        {
            if (c == '"')
            {
                if (i + 1 < csv.length && csv[i + 1] == '"')
                {
                    currentField ~= '"';
                    i += 2;
                }
                else
                {
                    inQuotes = false;
                    i++;
                }
            }
            else
            {
                currentField ~= c;
                i++;
            }
        }
        else
        {
            if (c == '"')
            {
                inQuotes = true;
                i++;
            }
            else if (c == ',')
            {
                currentRow ~= parseCell(currentField);
                currentField = null;
                i++;
            }
            else if (c == '\r')
            {
                i++;
                if (i < csv.length && csv[i] == '\n')
                    i++;

                currentRow ~= parseCell(currentField);
                currentField = null;
                ret ~= currentRow;
                currentRow = null;
            }
            else if (c == '\n')
            {
                i++;
                currentRow ~= parseCell(currentField);
                currentField = null;
                ret ~= currentRow;
                currentRow = null;
            }
            else
            {
                currentField ~= c;
                i++;
            }
        }
    }

    currentRow ~= parseCell(currentField);
    if (currentRow.length > 0)
        ret ~= currentRow;

    return ret;
}

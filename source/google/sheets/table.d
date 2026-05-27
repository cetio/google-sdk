module google.sheets.table;

import google.drive.ifile : IFile;
import google.sheets.cell : CellValue, CellType, parseCell;
import google.sheets.row : Row;

public:

enum TableType
{
    Snapshot,
    Live,
}

struct Range
{
    size_t start;
    size_t end;
}

struct Table
{
public:
    TableType type = TableType.Snapshot;
    IFile file;
    CellValue[][] data;

    size_t length() const
        => data.length;

    size_t opDollar() const
        => data.length;

    size_t opDollar(size_t dim)() const
    {
        static if (dim == 0)
            return data.length;
        else static if (dim == 1)
        {
            if (data.length == 0)
                return 0;

            size_t ret = data[0].length;
            foreach (CellValue[] row; data)
            {
                if (row.length > ret)
                    ret = row.length;
            }
            return ret;
        }
        else
            static assert(false, "Table only supports 2 dimensions.");
    }

    Row opIndex(size_t row)
    {
        if (row >= data.length)
            throw new Exception("Row index out of bounds.");

        return Row(data[row]);
    }

    CellValue opIndex(size_t row, size_t col)
    {
        if (row >= data.length)
            throw new Exception("Row index out of bounds.");

        if (col >= data[row].length)
            throw new Exception("Column index out of bounds.");

        return data[row][col];
    }

    Range opSlice(size_t dim)(size_t start, size_t end)
    {
        return Range(start, end);
    }

    Table opIndex(Range rows)
    {
        Table ret;
        ret.type = type;
        ret.file = file;

        foreach (size_t rowIndex; rows.start..rows.end)
        {
            if (rowIndex >= data.length)
                throw new Exception("Row slice out of bounds.");

            ret.data ~= data[rowIndex].dup;
        }

        return ret;
    }

    Table opIndex(Range rows, Range cols)
    {
        Table ret;
        ret.type = type;
        ret.file = file;

        foreach (size_t rowIndex; rows.start..rows.end)
        {
            if (rowIndex >= data.length)
                throw new Exception("Row slice out of bounds.");

            CellValue[] rowSlice;
            size_t actualEnd = cols.end;
            if (actualEnd > data[rowIndex].length)
                actualEnd = data[rowIndex].length;

            foreach (size_t colIndex; cols.start..actualEnd)
                rowSlice ~= data[rowIndex][colIndex];

            ret.data ~= rowSlice;
        }

        return ret;
    }

    Row opIndex(size_t row, Range cols)
    {
        if (row >= data.length)
            throw new Exception("Row index out of bounds.");

        CellValue[] rowSlice;
        size_t actualEnd = cols.end;
        if (actualEnd > data[row].length)
            actualEnd = data[row].length;

        foreach (size_t colIndex; cols.start..actualEnd)
            rowSlice ~= data[row][colIndex];

        return Row(rowSlice);
    }

    CellValue[] opIndex(Range rows, size_t col)
    {
        CellValue[] ret;
        foreach (size_t rowIndex; rows.start..rows.end)
        {
            if (rowIndex >= data.length)
                throw new Exception("Row slice out of bounds.");

            if (col >= data[rowIndex].length)
                throw new Exception("Column index out of bounds.");

            ret ~= data[rowIndex][col];
        }

        return ret;
    }

    static Table fromText(string csv, IFile file = null, TableType type = TableType.Snapshot)
    {
        Table ret;
        ret.type = type;
        ret.file = file;
        ret.data = parseCsv(csv);
        return ret;
    }
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

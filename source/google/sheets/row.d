module google.sheets.row;

import google.sheets.cell : CellValue;

public:

struct Row
{
public:
    CellValue[] cells;

    this(CellValue[] cells)
    {
        this.cells = cells;
    }

    CellValue opIndex(size_t col)
    {
        if (col >= cells.length)
            throw new Exception("Column index out of bounds.");

        return cells[col];
    }

    Row opSlice(size_t start, size_t end)
    {
        if (start > end || end > cells.length)
            throw new Exception("Invalid slice range.");

        return Row(cells[start..end]);
    }

    size_t length() const
        => cells.length;

    size_t opDollar() const
        => cells.length;
}

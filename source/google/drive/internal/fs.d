module google.drive.internal.fs;

import std.datetime : Clock, SysTime;
import std.conv : to;
import std.file;
import std.path : dirName, expandTilde;
import std.process : thisProcessID;

version (Posix)
{
    import core.sys.posix.sys.stat : chmod;
    import std.internal.cstring : tempCString;
}

public:

string makeTempSiblingPath(string path)
{
    string resolvedPath = resolvePath(path);
    SysTime timestamp = Clock.currTime();

    return resolvedPath~".tmp-"~thisProcessID.to!string~"-"~timestamp.stdTime.to!string;
}

void ensureDirectory(string path, uint mode = 0x1C0)
{
    string resolvedPath = resolvePath(path);
    if (resolvedPath == null)
        return;

    if (!exists(resolvedPath))
        mkdirRecurse(resolvedPath);

    setPermissions(resolvedPath, mode);
}

void atomicWriteBytes(string path, const(ubyte)[] data, uint mode = 0x180)
{
    string resolvedPath = resolvePath(path);
    string parent = dirName(resolvedPath);
    if (parent.length)
        ensureDirectory(parent);

    string tempPath = makeTempSiblingPath(resolvedPath);
    scope (failure)
    {
        if (exists(tempPath))
            remove(tempPath);
    }

    write(tempPath, cast(const(void)[])data);
    finalizeAtomicWrite(tempPath, resolvedPath, mode);
}

void atomicWriteText(string path, string text, uint mode = 0x180)
{
    atomicWriteBytes(path, cast(const(ubyte)[])text, mode);
}

void finalizeAtomicWrite(string tempPath, string finalPath, uint mode = 0x180)
{
    setPermissions(tempPath, mode);
    rename(tempPath, finalPath);
    setPermissions(finalPath, mode);
}

private:

string resolvePath(string path)
{
    return path == null ? null : expandTilde(path);
}

void setPermissions(string path, uint mode)
{
    version (Posix)
    {
        typeof(path.tempCString()) cPath = path.tempCString();
        chmod(cPath.ptr, mode);
    }
}

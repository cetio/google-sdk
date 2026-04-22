module gdrive.errors;

import std.exception : basicExceptionCtors;

public:

class GDriveError : Exception
{
    mixin basicExceptionCtors;
}

class GDriveAuthError : GDriveError
{
    mixin basicExceptionCtors;
}

class GDrivePermissionError : GDriveError
{
    mixin basicExceptionCtors;
}

class GDriveNotFoundError : GDriveError
{
    mixin basicExceptionCtors;
}

class GDriveRateLimitError : GDriveError
{
    mixin basicExceptionCtors;
}

class GDriveUnsupportedContentError : GDriveError
{
    mixin basicExceptionCtors;
}

class GDriveProtocolError : GDriveError
{
    mixin basicExceptionCtors;
}

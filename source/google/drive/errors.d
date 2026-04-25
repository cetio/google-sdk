module google.drive.errors;

import std.exception : basicExceptionCtors;

public:

class GoogleDriveError : Exception
{
    mixin basicExceptionCtors;
}

class GoogleDriveAuthError : GoogleDriveError
{
    mixin basicExceptionCtors;
}

class GoogleDrivePermissionError : GoogleDriveError
{
    mixin basicExceptionCtors;
}

class GoogleDriveNotFoundError : GoogleDriveError
{
    mixin basicExceptionCtors;
}

class GoogleDriveRateLimitError : GoogleDriveError
{
    mixin basicExceptionCtors;
}

class GoogleDriveUnsupportedContentError : GoogleDriveError
{
    mixin basicExceptionCtors;
}

class GoogleDriveProtocolError : GoogleDriveError
{
    mixin basicExceptionCtors;
}

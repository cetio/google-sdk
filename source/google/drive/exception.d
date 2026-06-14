module google.drive.exception;

import std.exception : basicExceptionCtors;

public:

class DriveException : Exception
{
    mixin basicExceptionCtors;
}

class DriveAuthException : DriveException
{
    mixin basicExceptionCtors;
}

class DrivePermissionException : DriveException
{
    mixin basicExceptionCtors;
}

class DriveNotFoundException : DriveException
{
    mixin basicExceptionCtors;
}

class DriveRateLimitException : DriveException
{
    mixin basicExceptionCtors;
}

class DriveUnsupportedContentException : DriveException
{
    mixin basicExceptionCtors;
}

class DriveProtocolException : DriveException
{
    mixin basicExceptionCtors;
}

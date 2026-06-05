module google.gmail.error;

import std.exception : basicExceptionCtors;

public:

class GmailError : Exception
{
    mixin basicExceptionCtors;
}

class GmailAuthError : GmailError
{
    mixin basicExceptionCtors;
}

class GmailPermissionError : GmailError
{
    mixin basicExceptionCtors;
}

class GmailNotFoundError : GmailError
{
    mixin basicExceptionCtors;
}

class GmailRateLimitError : GmailError
{
    mixin basicExceptionCtors;
}

class GmailProtocolError : GmailError
{
    mixin basicExceptionCtors;
}

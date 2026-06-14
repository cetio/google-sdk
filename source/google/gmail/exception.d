module google.gmail.exception;

import std.exception : basicExceptionCtors;

public:

class GmailException : Exception
{
    mixin basicExceptionCtors;
}

class GmailAuthException : GmailException
{
    mixin basicExceptionCtors;
}

class GmailPermissionException : GmailException
{
    mixin basicExceptionCtors;
}

class GmailNotFoundException : GmailException
{
    mixin basicExceptionCtors;
}

class GmailRateLimitException : GmailException
{
    mixin basicExceptionCtors;
}

class GmailProtocolException : GmailException
{
    mixin basicExceptionCtors;
}

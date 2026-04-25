module google.drive.internal.config;

import std.path : buildPath, expandTilde;
import std.process : environment;
import std.string : startsWith;

public:

struct AccountConfig
{
    string clientCredentialsPath = "~/.config/galah/google-oauth-client.json";
    string tokenStoreDir = "~/.local/state/galah/google-sdk/accounts";
    string applicationName = "Galah";
    bool supportsAllDrives = false;
}

AccountConfig resolveAccountConfig(AccountConfig config)
{
    AccountConfig ret = config;

    ret.clientCredentialsPath = resolveUserFacingPath(ret.clientCredentialsPath);
    ret.tokenStoreDir = resolveUserFacingPath(ret.tokenStoreDir);
    if (ret.applicationName == null)
        ret.applicationName = "Galah";

    return ret;
}

string resolveUserFacingPath(string path)
{
    string ret = path;

    if (ret == null)
        return ret;

    if (ret.startsWith("~/.config/"))
    {
        string base = environment.get("XDG_CONFIG_HOME");
        if (base != null)
            return buildPath(base, ret["~/.config/".length..$]);
    }
    else if (ret.startsWith("~/.local/state/"))
    {
        string base = environment.get("XDG_STATE_HOME");
        if (base != null)
            return buildPath(base, ret["~/.local/state/".length..$]);
    }

    ret = expandTilde(ret);
    return ret;
}

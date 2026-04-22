module gdrive.test.dummy.testserver;

import composer.query : parseQuery;
import core.thread : Thread;
import std.conv : to;
import std.exception : enforce;
import std.socket;
import std.string : indexOf, split, splitLines;
import std.uni : toLower;

public:

struct TestRequest
{
    string method;
    string target;
    string path;
    string queryString;
    string[string] query;
    string[string] headers;
    ubyte[] content;
}

struct TestResponse
{
    ushort status = 200;
    string reason = "OK";
    string[string] headers;
    ubyte[] content;
}

alias TestHandler = TestResponse delegate(TestRequest request);

class SimpleHttpServer
{
private:
    Socket listener;
    TestHandler handler;

public:
    ushort port()
        => (cast(InternetAddress)listener.localAddress).port;

    string baseUrl()
        => "http://127.0.0.1:"~to!string(port());

    this(TestHandler handler)
    {
        this.handler = handler;
        listener = new Socket(AddressFamily.INET, SocketType.STREAM);
        listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        listener.bind(new InternetAddress("127.0.0.1", InternetAddress.PORT_ANY));
        listener.listen(8);
        spawn();
    }

    void close()
    {
        if (listener !is null)
        {
            listener.close();
            listener = null;
        }
    }

private:
    void spawn()
    {
        Socket localListener = listener;
        TestHandler localHandler = handler;

        Thread thread = new Thread({
            while (true)
            {
                Socket client;
                try
                    client = localListener.accept();
                catch (Throwable)
                {
                    break;
                }

                scope (exit)
                {
                    if (client !is null)
                        client.close();
                }

                TestRequest request = readRequest(client);
                TestResponse response = localHandler(request);
                writeResponse(client, response);
            }
        });
        thread.isDaemon(true);
        thread.start();
    }

    TestRequest readRequest(Socket client)
    {
        TestRequest ret;
        ubyte[] buffer;
        ubyte[1024] chunk = void;

        while (findHeaderTerminator(buffer) < 0)
        {
            ptrdiff_t received = client.receive(chunk[]);
            if (received <= 0)
                break;

            buffer ~= chunk[0..received];
        }

        int headerEnd = findHeaderTerminator(buffer);
        enforce(headerEnd >= 0, "Test server did not receive a complete HTTP header block.");

        string headerText = cast(string)buffer[0..headerEnd].idup;
        ret = parseRequest(headerText);

        size_t contentOffset = headerEnd + 4;
        size_t contentLength = ret.headers.get("content-length", "0").to!size_t;
        ubyte[] content = buffer.length > contentOffset ? buffer[contentOffset..$].dup : null;

        while (content.length < contentLength)
        {
            ptrdiff_t received = client.receive(chunk[]);
            if (received <= 0)
                break;

            content ~= chunk[0..received];
        }

        if (content.length > contentLength)
            content.length = contentLength;

        ret.content = content;
        return ret;
    }

    TestRequest parseRequest(string headerText)
    {
        TestRequest ret;
        string[] lines = splitLines(headerText);
        enforce(lines.length > 0, "Test server received an empty request.");

        string[] requestLine = lines[0].split(" ");
        enforce(requestLine.length >= 2, "Test server received a malformed request line.");

        ret.method = requestLine[0];
        ret.target = requestLine[1];

        ptrdiff_t questionMark = ret.target.indexOf('?');
        if (questionMark < 0)
        {
            ret.path = ret.target;
        }
        else
        {
            ret.path = ret.target[0..questionMark];
            ret.queryString = ret.target[questionMark + 1..$];
            ret.query = parseQuery(ret.queryString);
        }

        foreach (string line; lines[1..$])
        {
            if (line == "")
                break;

            ptrdiff_t separator = line.indexOf(": ");
            if (separator <= 0)
                continue;

            ret.headers[toLower(line[0..separator])] = line[separator + 2..$];
        }

        return ret;
    }

    void writeResponse(Socket client, TestResponse response)
    {
        string[string] headers = response.headers;
        if (("content-length" in headers) is null)
            headers["content-length"] = response.content.length.to!string;

        string headerText = "HTTP/1.1 "~response.status.to!string~" "~response.reason~"\r\n";
        foreach (string key, string value; headers)
            headerText ~= key~": "~value~"\r\n";
        headerText ~= "\r\n";

        client.send(cast(const(ubyte)[])headerText);
        if (response.content != null)
            client.send(response.content);
    }

    int findHeaderTerminator(const(ubyte)[] bytes)
    {
        if (bytes.length < 4)
            return -1;

        foreach (size_t idx; 0..bytes.length - 3)
        {
            if (bytes[idx] == '\r' && bytes[idx + 1] == '\n' && bytes[idx + 2] == '\r' && bytes[idx + 3] == '\n')
                return cast(int)idx;
        }

        return -1;
    }
}

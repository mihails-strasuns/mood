module mood.main;

// ignore this module during tests
version(unittest) { }
else:

import mood.config;
import mood.application;

import vibe.core.core;
import vibe.core.log;

import vibe.http.server;
import vibe.http.router;
import vibe.http.fileserver;

import vibe.web.rest;

void main(string[] args)
{
    setLogLevel(LogLevel.info);
    auto app = MoodApp.initialize();

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = [ "::1", "127.0.0.1" ];

    auto router = new URLRouter;
    // protected sections require authorization first before route fall-through
    router.get("/testauth", &basic_auth);
    router.post(MoodURLConfig.apiBase ~ MoodURLConfig.posts, &basic_auth);

    // "real" request handlers
    router.registerRestInterface(app.API());
    router.get(MoodURLConfig.posts, &app.postHTML);
    router.get("*", serveStaticFiles(Path(MoodPathConfig.statics)));

    listenHTTP(settings, router);
    runEventLoop();
}

void basic_auth(HTTPServerRequest req, HTTPServerResponse res)
{
    import std.base64;
    import std.format : format;
    import std.exception : enforce;

    res.headers["WWW-Authenticate"] = "Basic realm=\"" ~ MoodAuthConfig.realm ~ "\"";

    if (!req.ssl)
    {
        auto url = req.fullURL();
        url.schema = "https";
        res.redirect(url);
        return;
    }

    auto auth = req.headers.getAll("Auhtorization");
    if (auth.length != 1)
        throw new HTTPStatusException(HTTPStatus.unauthorized);

    auto expected = format(
        "Basic %s",
        Base64.encode(cast(ubyte[]) format(
            "%s:%s", MoodAuthConfig.user, MoodAuthConfig.password))
    );

    if (auth[0] != expected)
        throw new HTTPStatusException(HTTPStatus.unauthorized);
}

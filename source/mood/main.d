module mood.main;

// ignore this module during tests
version(unittest) { }
else:

import mood.config;
import mood.application;
import mood.api.implementation;

import vibe.core.core;
import vibe.core.log;
import vibe.core.path;

import vibe.http.server;
import vibe.http.router;
import vibe.http.fileserver;

import vibe.web.rest;
import vibe.web.web;

void main(string[] args)
{
    setLogLevel(LogLevel.info);

    version (MoodWithPygmentize)
    {
        {
            import std.process;
            import std.exception;
            auto ret = executeShell("pygmentize -h");
            enforce(
                ret.status == 0,
                "Mood was compiled with 'pygmentize' support but " ~
                    "it wasn't found via PATH"
            );
        }
    }

    auto api = new MoodAPI();
    auto app = new MoodApp(api);

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.options |= HTTPServerOption.distribute;

    import vibe.stream.tls;
    settings.bindAddresses = [ "::1", "127.0.0.1" ];
    settings.tlsContext = createTLSContext(TLSContextKind.server);
    settings.tlsContext.useCertificateChainFile("certs/blog.crt");
    settings.tlsContext.usePrivateKeyFile("certs/blog.key");

    auto router = new URLRouter;

    // protected sections require authorization first before route fall-through
    import vibe.http.auth.basic_auth;
    auto auth_dg = performBasicAuth(
        MoodAuthConfig.realm,
        (user, pwd) => user == MoodAuthConfig.user && pwd == MoodAuthConfig.password
    );
    // for rendering handlers auth as added via @auth attribute but REST mdoule
    // does not support anything like that yet
    router.post("/api/*", auth_dg);

    // "real" request handlers
    router.registerRestInterface(api);
    router.registerWebInterface(app);
    // by default serve post feed
    router.get("/", &app.lastBlogPosts);
    // anything unhandled should be checked for presence in statics folder
    router.get("*", serveStaticFiles(NativePath(MoodPathConfig.statics)));

    listenHTTP(settings, router);
    runEventLoop();
}

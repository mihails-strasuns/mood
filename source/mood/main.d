module mood.main;

// ignore this module during tests
version(unittest) { }
else:

import mood.config;
import mood.application;

import mood.util.route_attr;

import vibe.core.core;
import vibe.core.log;

import vibe.http.server;
import vibe.http.router;
import vibe.http.fileserver;

import vibe.web.rest;

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

    auto app = new MoodApp();

    auto settings = new HTTPServerSettings;
    settings.port = 8081;
    settings.options |= HTTPServerOption.distribute;

    import vibe.stream.ssl;
    settings.bindAddresses = [ "::1", "127.0.0.1" ];
    settings.sslContext = createSSLContext(SSLContextKind.server);
    settings.sslContext.useCertificateChainFile("certs/blog.crt");
    settings.sslContext.usePrivateKeyFile("certs/blog.key");

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

    // redirects for backwards compatibility with old Blogpost-hosted stuff
    router.get(
        "2014/12/making-sure-your-d-projects-wont-break.html",
        staticRedirect("2014/12/making_sure_your_d_projects_wont_break",
            HTTPStatus.MovedPermanently)
    );
    router.get(
        "2015/01/thoughts-about-rust-from-d-programmer.html",
        staticRedirect("2015/01/thoughts_about_rust_from_d_programmer",
            HTTPStatus.MovedPermanently)
    );

    // "real" request handlers
    router.registerRestInterface(app.API());
    router.register(app, auth_dg);
    // by default serve post feed
    router.get("/", &app.lastBlogPosts);
    // anything unhandled should be checked for presence in statics folder
    router.get("*", serveStaticFiles(Path(MoodPathConfig.statics)));

    listenHTTP(settings, router);
    runEventLoop();
}

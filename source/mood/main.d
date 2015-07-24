module mood.main;

// ignore this module during tests
version(unittest) { }
else:

import mood.config;
import mood.application;

import extra.routing;

import vibe.core.core;
import vibe.core.log;

import vibe.http.server;
import vibe.http.router;
import vibe.http.fileserver;

import vibe.web.rest;

void main(string[] args)
{
    setLogLevel(LogLevel.trace);
    auto app = new MoodApp();

    auto settings = new HTTPServerSettings;
    settings.port = 8080;

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
    router.post(MoodURLConfig.apiBase ~ MoodURLConfig.posts, auth_dg);

    // "real" request handlers
    router.registerRestInterface(app.API());
    router.register(app, auth_dg);
    router.get ("*", serveStaticFiles(Path(MoodPathConfig.statics)));

    listenHTTP(settings, router);
    runEventLoop();
}

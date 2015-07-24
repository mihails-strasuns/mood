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
    router.any (MoodURLConfig.admin, auth_dg);
    router.post(MoodURLConfig.posts, auth_dg);
    router.post(MoodURLConfig.apiBase ~ MoodURLConfig.posts, auth_dg);

    // "real" request handlers
    router.registerRestInterface(app.API());
    router.register(app);
    router.get  ("*", serveStaticFiles(Path(MoodPathConfig.statics)));

    listenHTTP(settings, router);
    runEventLoop();
}

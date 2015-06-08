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

void main(string[] args)
{
    // setLogLevel(LogLevel.trace);
    auto app = MoodApp.initialize();

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = [ "::1", "127.0.0.1" ];

    auto router = new URLRouter;
    router.get(MoodURLConfig.postsPrefix, &app.postHTML);
    router.get("*", serveStaticFiles(Path(MoodPathConfig.statics)));

    listenHTTP(settings, router);
    runEventLoop();
}

import std.regex;

import vibe.core.log;
import vibe.core.file;
import vibe.http.server;
import vibe.http.router;
import vibe.http.fileserver;
import vibe.templ.diet;
import vibe.stream.memory;
import vibe.web.rest;

import types;
import pages;
import api;
import markdown;

shared static this()
{
    Settings settings;
    settings.path = Path("./demo/");

    auto httpSettings = new HTTPServerSettings;
    httpSettings.port = 8080;
    httpSettings.bindAddresses = ["::1", "127.0.0.1"];

    auto router = new URLRouter;
    router.get("/post", &post);
    router.get("/demoArticles", &demoArticles);
    router.get("*", makeMarkdownServer(settings));
    router.get("*", serveStaticFiles(settings.path ~ Path("static")));

    registerRestInterface(router, new API(settings));

    listenHTTP(httpSettings, router);
}

void post(HTTPServerRequest req, HTTPServerResponse res)
{
    wrapPage(compileTemplate!("post.dt"), res.bodyWriter);
}

void demoArticles(HTTPServerRequest req, HTTPServerResponse res)
{
    wrapContent("Lorem Ipsum", compileTemplate!("demoArticles.dt"), res.bodyWriter);
}

auto pathRegex = regex(r"\.\.+");
auto makeMarkdownServer(Settings settings)
{
    auto serve(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto path = Path(replaceAll(req.path, pathRegex, "."));

        auto markdown = parseMarkdown(path, settings);
        if (!markdown)
            return;

        wrapContent("Lorem Ipsum", markdown.content, res.bodyWriter);
    }

    return &serve;
}

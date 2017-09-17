/**
    Provides main mood application data type which is intended
    to encapsulate internal data with relevant HTTP request handlers.

    Taking care of higher level routing, CLI and program startup in
    general is responsibility of actual `main` function though.
 */
module mood.application;

import vibe.core.log;
import vibe.web.common;

/**
    Application data type
 */
class MoodApp
{
    import vibe.http.server;
    import vibe.inet.path : Path;

    import mood.config;
    import mood.api.implementation;
    import HTML = mood.rendering.html;
    import RSS = mood.rendering.rss;

    private MoodAPI api;

    /**
        Creates application instance and initializes it from
        the disk data if present
     */
    this()
    {
        this.api = new MoodAPI;
    }

    unittest
    {
        auto app = new MoodApp;
        assert (app.api !is null);
    }

    /**
        Requests that don't need rendering are served by RESTful API object

        Returns:
            RESTful API object used by this application renderers
     */
    MoodAPI API()
    {
        return this.api;
    }

    /**
        Renders page with latest blog post feed, sorted by date

        Each post is rendered in form of short summary and link to dedicated
        post page.

        Query parameters:
            n = controls how many posts to render on this page
            tag = show only posts that have this specified tag
     */
    @path("/posts") @method(HTTPMethod.GET)
    void lastBlogPosts(HTTPServerRequest req, HTTPServerResponse res)
    {
        void renderer(uint n, string tag)
        {
            auto last_posts = this.api.getPosts(MoodViewConfig.sidePanelSize);
            auto posts = this.api.getPosts(n, tag);
            res.headers["Content-Type"] = "text/html; charset=UTF-8";
            HTML.renderIndex(res.bodyWriter, posts, last_posts);
        }

        this.feedOptionsFromRequest(req, &renderer);
    }

    /**
        Renders RSS XML feed for latest blog posts. Query parameter `n`
        control

        Query parameters:
            n = controls how many posts to render on this page
            tag = show only posts that have this specified tag
     */
    @path("/posts.rss") @method(HTTPMethod.GET)
    void lastBlogPostRSS(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.string : format;

        void renderer(uint n, string tag)
        {
            auto posts = this.api.getPosts(n, tag);
            res.headers["Content-Type"] = "text/xml; charset=UTF-8";
            RSS.renderFeed(res.bodyWriter, posts);
        }

        this.feedOptionsFromRequest(req, &renderer);
    }

    /**
        Renders page with full content for a specific blog post

        Each post URL is supposed to be in form of /YYYY/MM/title
     */
    @path("/posts/*") @method(HTTPMethod.GET)
    void singleBlogPost(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.regex;
        static post_pattern = ctRegex!(r"\d{4}/\d{2}/.+$");

        auto capture = matchFirst(req.path, post_pattern);
        if (!capture.empty)
        {
            auto last_posts = this.api.getPosts(MoodViewConfig.sidePanelSize);

            BlogPost entry;

            try
            {
                entry = this.api.getPost(capture.hit);
            }
            catch (HTTPStatusException)
            {
                logTrace("Missing entry '%s' was requested", capture.hit);
                return;
            }

            HTML.renderSinglePost(res.bodyWriter, entry, last_posts);
        }
    }

    private void feedOptionsFromRequest(HTTPServerRequest req,
        void delegate (uint n, string tag) renderer)
    {
        import std.conv : to;

        // how many posts to retrieve
        auto n = to!uint(req.query.get("n", "5"));
        // show only posts with specific tag in feed
        auto tag = req.query.get("tag", "");

        renderer(n, tag);
    }
}

version (unittest)
{
    static this ()
    {
        setLogLevel(LogLevel.fatal);
    }
}

unittest
{
    import vibe.http.server;
    import vibe.inet.url;
    import vibe.stream.memory;

    auto app = new MoodApp;
    auto req = createTestHTTPServerRequest(URL("/posts"), HTTPMethod.GET);
    auto res_stream = createMemoryOutputStream();
    auto res = createTestHTTPServerResponse(res_stream);

    // best approach to testing is yet unclear
    // only check that nothing gets thrown for empty request
    app.lastBlogPosts(req, res);
    app.singleBlogPost(req, res);
}

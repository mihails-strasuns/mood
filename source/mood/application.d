/**
    Provides main mood application data type which is intended
    to encapsulate internal data with relevant HTTP request handlers.

    Taking care of higher level routing, CLI and program startup in
    general is responsibility of actual `main` function though.
 */
module mood.application;

import vibe.core.log;
import vibe.web.common;

import mood.util.route_attr;

/**
    Application data type

    Take 
 */
class MoodApp
{
    import vibe.http.server;
    import vibe.inet.path : Path;

    import mood.config;
    import mood.api.implementation;

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
        auto options = this.feedOptionsFromRequest(req);
        auto posts = this.api.getPosts(options.n, options.tag);

        import std.range : take;
        auto last_posts = this.api.getPosts(MoodViewConfig.sidePanelSize);

        res.render!("pages/index.dt", posts, last_posts);
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

        auto options = this.feedOptionsFromRequest(req);
        auto posts = this.api.getPosts(options.n, options.tag);

        string base_url = "INSERT-YOUR-URL";

        string genItem(const mood.api.spec.BlogPost post)
        {
            return format(
                "<item><title>%s</title><link>%s</link><pubDate>%s</pubDate></item>\n",
                post.title,
                base_url ~ "/" ~ post.relative_url,
                post.created_at.toISOString()
            );
        }

        import std.algorithm : map;
        import std.range : join;
        auto feed = posts.map!genItem.join();
          
        auto xml = format(
            // feed data
            "<?xml version='1.0' encoding='UTF-8' ?><rss version='2.0'>\n"
                ~ "<channel>\n<title>INSERT-YOUR-TITLE</title>\n"
                ~ "<link>%s</link>\n%s</channel>\n</rss>",
            base_url,
            feed
        );

        res.writeBody(xml);
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
            try
            {
                auto entry = this.api.getPost(capture.hit);
                auto title = entry.title;
                auto content = entry.html_full;

                import std.range : take;
                auto last_posts = this.api.getPosts(MoodViewConfig.sidePanelSize);

                res.render!("pages/single_post.dt", title, content, last_posts);
            }
            catch (HTTPStatusException)
            {
                logTrace("Missing entry '%s' was requested", capture.hit);
                return;
            }
        }
    }

    /**
        Processes POST request with a form data for adding new post

        After gathering necessary data processing is forwarded to REST API
        implementation
     */
    @path("/posts") @method(HTTPMethod.POST) @auth
    void processNewBlogPost(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.exception : enforce;
        auto title   = req.form["title"];
        auto content = req.form["content"];
        enforce(title.length != 0 && content.length != 0);

        auto url = this.api.addPost(title, content).url;
        res.redirect("/posts/" ~ url);
    }

    /**
        Renders privileged access page which serves as entry point for any
        modifications of blog data via web interfaces

        Currently only allows adding new posts
     */
    @path("/admin") @method(HTTPMethod.GET) @auth
    void administration(HTTPServerRequest req, HTTPServerResponse res)
    {
        res.render!("pages/new_post.dt");
    }

    private auto feedOptionsFromRequest(HTTPServerRequest req)
    {
        struct FeedOptions
        {
            // how many posts to retrieve
            uint n;
            // show only posts with specific tag in feed
            string tag;
        }

        import std.conv : to;

        auto n = to!uint(req.query.get("n", "5"));
        auto tag = req.query.get("tag", "");

        return FeedOptions(n, tag);
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
    auto res_stream = new MemoryOutputStream;
    auto res = createTestHTTPServerResponse(res_stream);

    // best approach to testing is yet unclear
    // only check that nothing gets thrown for empty request
    app.lastBlogPosts(req, res);

    app.singleBlogPost(req, res);

    // disabled for now because it does I/O
    /*
    req.form["title"] = "aaa";
    req.form["content"] = "bbb";
    app.processNewBlogPost(req, res);
    */

    app.administration(req, res);
}

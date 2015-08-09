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

    Mood uses one instance of this struct to handle HTTP requests
    that need access to cached in-memory data
 */
class MoodApp
{
    import vibe.http.server;
    import vibe.inet.path : Path;

    import mood.cache.posts;
    import mood.config;
    import mood.api.implementation;

    private
    {
        BlogPosts cache;
        MoodAPI   api;
    }

    /**
        Creates application instance and initializes it from
        the disk data if present

        Params:
            load_cache = if set to 'false', no data loading happens automatically
     */
    this(bool load_cache = true)
    {
        logInfo("Initializing Mood application");

        if (load_cache)
        {
            auto markdown_sources = Path(MoodPathConfig.markdownSources);
            logInfo("Looking for blog post sources at %s", markdown_sources);
            this.cache.loadFromDisk(markdown_sources);
            logInfo("%s posts loaded", this.cache.posts_by_url.length);
            import std.range : join;
            logTrace("\t%s", this.cache.posts_by_url.keys.join("\n\t"));
        }

        logInfo("Initializing Mood RESTful API");
        this.api = new MoodAPI(this.cache);

        logInfo("Application data is ready");
    }

    unittest
    {
        auto app = new MoodApp(false);
        assert (app.cache.posts_by_url.length == 0);
        assert (app.api !is null);
    }

    /**
        Requests that don't need rendering are served by RESTful API object

        Returns:
            RESTful API object bound to this application cache
     */
    MoodAPI API()
    {
        return this.api;
    }

    /**
        Renders page with latest blog post feed, sorted by date

        Each post is rendered in form of short summary and link to dedicated
        post page. Query parameter `n` control how many posts to render on
        this page
     */
    @path("/posts") @method(HTTPMethod.GET)
    void lastBlogPosts(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.conv : to;

        // how many posts to retrieve
        auto n = to!uint(req.query.get("n", "5"));

        // show only posts with specific tag in feed
        auto tag_filter = req.query.get("tag", "");

        import std.algorithm : filter;
        import std.range : take;

        // predicate to check if specific blog posts has required tag
        // always 'true' if there is no tag filter defined
        bool hasTag(const BlogPost* post)
        {
            if (tag_filter.length == 0)
                return true;

            foreach (tag; post.tags)
            {
                if (tag == tag_filter)
                    return true;
            }

            return false;
        }

        auto posts = this.cache.posts_by_date
            .filter!hasTag
            .take(n);
        auto posts_by_date = this.cache.posts_by_date;
        res.render!("pages/index.dt", posts, posts_by_date);
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
            auto entry = capture.hit in this.cache.posts_by_url;
            if (entry !is null)
            {
                auto title = entry.title;
                auto content = entry.html_full;
                auto posts_by_date = this.cache.posts_by_date;
                res.render!("pages/single_post.dt", title, content, posts_by_date);
            }
            else
                logTrace("Missing entry '%s' was requested", capture.hit);
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

    auto app = new MoodApp(false);
    auto req = createTestHTTPServerRequest(URL("/posts"), HTTPMethod.GET);
    auto res_stream = new MemoryOutputStream;
    auto res = createTestHTTPServerResponse(res_stream);

    // best approach to testing is yet unclear
    // only check that nothing gets thrown for empty request
    app.lastBlogPosts(req, res);

    app.singleBlogPost(req, res);

    req.form["title"] = "aaa";
    req.form["content"] = "bbb";
    app.processNewBlogPost(req, res);

    app.administration(req, res);
}

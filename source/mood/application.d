/**
    Provides main mood application data type which is intended
    to encapsulate internal data with relevant HTTP request handlers.

    Taking care of higher level routing, CLI and program startup in
    general is responsibility of actual `main` function though.
 */
module mood.application;

import vibe.core.log;

/**
    Application data type

    Mood uses one instance of this struct to handle HTTP requests
    that need access to cached in-memory data
 */
struct MoodApp
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

    // no default construction, use initialize() instead
    @disable this();

    /**
        Creates application instance and initializes it from
        the disk data if present
     */
    static MoodApp initialize()
    {
        import std.range : join;

        logInfo("Initializing Mood application");
        auto app = MoodApp.init;

        auto markdown_sources = Path(MoodPathConfig.markdownSources);
        logInfo("Looking for blog post sources at %s", markdown_sources);
        app.cache.loadFromDisk(markdown_sources);
        logInfo("%s posts loaded", app.cache.posts_by_url.length);
        logTrace("\t%s", app.cache.posts_by_url.keys.join("\n\t"));

        logInfo("Initializing Mood RESTful API");
        app.api = new MoodAPI(app.cache);

        logInfo("Application data is ready");
        return app;
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
        Renders page for a single blog post
     */
    void postHTML(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.regex;
        static post_pattern = regex(r"\d{4}/\d{2}/.+$");

        auto capture = matchFirst(req.path, post_pattern);
        if (!capture.empty)
        {
            auto pcontent = capture.hit in this.cache.posts_by_url;
            if (pcontent !is null)
            {
                auto title = "Title";
                auto content = *pcontent;
                res.render!("single_post.dt", title, content);
            }
            else
                logTrace("Missing entry '%s' was requested", capture.hit);
        }
    }

    /**
        Adds new post
     */
    void addPost(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.exception : enforce;
        auto title   = req.form["title"];
        auto content = req.form["content"];
        enforce(title.length != 0 && content.length != 0);

        auto url = this.api.addPost(title, content).url;
        res.redirect(MoodURLConfig.posts ~ "/" ~ url);
    }

    /**
        Renders admin page for adding new blog post
     */
    void admin(HTTPServerRequest req, HTTPServerResponse res)
    {
        res.render!("new_post.dt");
    }
}

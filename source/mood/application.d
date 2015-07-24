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
     */
    this()
    {
        logInfo("Initializing Mood application");

        auto markdown_sources = Path(MoodPathConfig.markdownSources);
        logInfo("Looking for blog post sources at %s", markdown_sources);
        this.cache.loadFromDisk(markdown_sources);
        logInfo("%s posts loaded", this.cache.posts_by_url.length);
        import std.range : join;
        logTrace("\t%s", this.cache.posts_by_url.keys.join("\n\t"));

        logInfo("Initializing Mood RESTful API");
        this.api = new MoodAPI(this.cache);

        logInfo("Application data is ready");
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
    @path(MoodURLConfig.posts ~ "/*") @method(HTTPMethod.GET)
    void postHTML(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.regex;
        static post_pattern = regex(r"\d{4}/\d{2}/.+$");

        auto capture = matchFirst(req.path, post_pattern);
        if (!capture.empty)
        {
            auto entry = capture.hit in this.cache.posts_by_url;
            if (entry !is null)
            {
                auto title = entry.title;
                auto content = entry.html;
                res.render!("single_post.dt", title, content);
            }
            else
                logTrace("Missing entry '%s' was requested", capture.hit);
        }
    }

    /**
        Adds new post
     */
    @path(MoodURLConfig.posts) @method(HTTPMethod.POST)
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
    @path(MoodURLConfig.admin) @method(HTTPMethod.GET)
    void admin(HTTPServerRequest req, HTTPServerResponse res)
    {
        res.render!("new_post.dt");
    }
}

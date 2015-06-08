module mood.application;

import vibe.core.log;

struct MoodApp
{
    import vibe.http.server;
    import vibe.inet.path : Path;

    import mood.cache.md;
    import mood.cache.html;
    import mood.config;

    private
    {
        MarkdownCache md_cache;
        HTMLCache     html_cache;
    }

    // no default construction, use create() instead
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
        app.md_cache = MarkdownCache(app.html_cache);

        auto markdown_sources = Path(MoodPathConfig.markdownSources);
        logInfo("Looking for blog post sources at %s", markdown_sources);
        app.md_cache.loadFromDisk(markdown_sources);
        logInfo("%s posts loaded", app.html_cache.posts_by_url.length);
        logTrace("\t%s", app.html_cache.posts_by_url.keys.join("\n\t"));

        logInfo("Application data is ready");
        return app;
    }

    /**
     */
    void postHTML(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.regex;
        static post_pattern = regex(r"\d{4}/\d{2}/\d{2}/.+$");

        auto capture = matchFirst(req.path, post_pattern);
        if (!capture.empty)
        {
            auto pcontent = capture.hit in this.html_cache.posts_by_url;
            if (pcontent !is null)
            {
                auto title = "Title";
                auto content = *pcontent;
                res.render!("content.dt", title, content);
            }
        }
    }
}

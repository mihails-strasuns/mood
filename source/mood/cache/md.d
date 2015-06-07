/**
    Cache used to store markdown sources of blog posts.

    Operating on this cache automatically regenerates linked blog post HTML
    cache to ensure consistency of in-memory data.
 */
module mood.cache.md;

import mood.cache.core;
import mood.cache.html;

/// Cache used to store markdown sources of blog posts.
struct MarkdownCache
{
    import vibe.inet.path : Path;

    private HTMLCache* html;

    /// cached markdown sources
    Cache md;
    alias md this;

    /**
        Params:
            html = paired blog post cached to be updated when any of sources
                change
     */
    this(ref HTMLCache html)
    {
        this.html = &html;
    }

    /**
        Adds new markdown source to cache, rebuilding it and triggering
        rebuild of HTML cache as well.

        Params:
            key = relative URL of the blog post
            data = markdown source
     */
    void add(string key, string data)
    {
        this.md.replaceWith(this.md.add(key, data));
        this.html.render(key, data);
    }

    /**
        Scans file system for markdown sources and builds a new cache
        based on that, replacing the current one.

        Params:
            root_path = directory where all .md files are stored
     */
    void loadFromDisk(Path root_path)
    {
        this.md.replaceWith(this.md.loadFromDisk(root_path, ".md"));
        this.html.render(this.md);
    }
}

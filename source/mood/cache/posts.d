module mood.cache.posts;

import mood.cache.core;

struct BlogPost
{
    string   md;

    string   title;
    string   html;

    static BlogPost create(string source)
    {
        import vibe.textfilter.markdown;

        BlogPost entry;
        entry.md      = source;
        entry.title   = "TODO";
        entry.html    = filterMarkdown(source, MarkdownFlags.backtickCodeBlocks);
        return entry;
    }
}

struct BlogPosts
{
    import vibe.inet.path : Path;

    Cache!BlogPost cache;
    alias cache this;

    auto posts_by_url()
    {
        return this.cache.entries;
    }

    ref typeof(this) add(string key, string data) 
    {
        this.cache.replaceWith(this.cache.add(key, data));
        return this;
    }

    /**
        Scans file system for markdown sources and builds a new cache
        based on that, replacing the current one.

        Params:
            root_path = directory where all .md files are stored
     */
    void loadFromDisk(Path root_path)
    {
        this.cache.replaceWith(this.cache.loadFromDisk(root_path, ".md"));
    }
}

unittest
{
    BlogPosts cache;

    cache.add("/url", "# abcd");
    assert (cache.posts_by_url["/url"].html == "<h1> abcd</h1>\n");

    cache.clear();
    cache.replaceWith(cache.add("/block/1", "# a"));
    cache.replaceWith(cache.add("/block/2", "## b"));
    cache.replaceWith(cache.add("/block/3", "### c"));

    assert (cache.posts_by_url["/block/1"].html == "<h1> a</h1>\n");
    assert (cache.posts_by_url["/block/2"].html == "<h2> b</h2>\n");
    assert (cache.posts_by_url["/block/3"].html == "<h3> c</h3>\n");
}

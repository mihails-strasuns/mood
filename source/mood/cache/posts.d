/**
    Module that defines data model for a blog post

    Provides struct definition for a single blog post data and cache implementation
    to store those
 */
module mood.cache.posts;

import vibe.core.log;
import mood.cache.core;

/**
    Aggregates single blog post content and any related metadata

    Used as a cache element. `BlogPosts` will call `BlogPost.create`
    when loading dumped blog post data from disk to interpret it in
    meaningful way
    
    All non-static methods must be defined to work on const `this`
 */
struct BlogPost
{
    import std.datetime;

    /// Markdown sources for the blog post
    string md;
    /// Post title
    string title;
    /// Part of rendered blog post HTML used for short preview
    string html_intro;
    /// Full rendered blog post HTML
    string html_full;
    /// Post creation date
    SysTime created_at;
    /// Relative path/url for that specific post (also used as cache key)
    string relative_url;

    /**
        Keeps only date part of creation timestamp and formats it in
        a simple human-readable form (with a month as a word)

        Returns:
            formatted date string for insertion into rendered pages
     */
    string pretty_date() const @property
    {
        return (cast(Date) this.created_at).toSimpleString();
    }

    /**
        Creates a new blog post data entry from a given raw source

        Supported metadata fields: Title, Date

        Params:
            key = relative path that source was loaded from
            src = raw source for the post. Must be Markdown with
                meatdata embedded as HTML comments

        Returns:
            new blog post data, by value
     */
    static BlogPost create(string key, string src)
    {
        import vibe.textfilter.markdown;
        import std.regex, std.string;

        BlogPost entry;
        entry.relative_url = key;
        entry.md = src;
        entry.html_full = filterMarkdown(src, MarkdownFlags.backtickCodeBlocks);

        // If text has any headers, all content before the first header will
        // be used as preview. Otherwise full content will be used as preview.
        static first_header = ctRegex!(r"\n#+\s.+\n");
        auto possible_intro = src.matchFirst(first_header);
        if (!possible_intro.empty)
        {
            entry.html_intro = filterMarkdown(
                possible_intro.pre,
                MarkdownFlags.backtickCodeBlocks
            );
        }
        else
            entry.html_intro = entry.html_full;

        static first_comment = ctRegex!(r"<!--([^-]+)-->");
        auto possible_metadata = src.matchFirst(first_comment);

        if (!possible_metadata.empty)
        {
            auto metadata = strip(possible_metadata[1]);
            parseMetadata(metadata, entry);
        }

        return entry;
    }

    // parses metadats expected in HTML comments in `src` and fills
    // `dst` with it
    private static void parseMetadata(string src, ref BlogPost dst)
    {
        import std.regex, std.string;

        static key_value = ctRegex!(r"^([^:]+): (.+)$");

        foreach (line; src.splitLines())
        {
            auto pair = line.matchFirst(key_value);
            if (!pair.empty)
            {
                auto key = pair[1];
                auto value = pair[2];

                if (key == "Title")
                    dst.title = value;
                else if (key == "Date")
                    dst.created_at = SysTime.fromISOString(value);
            }
        }
    }
}

/**
    Immutable data cache for collection of `BlogPost` entries

    Builds on top of `mood.cache.core.Cache` adding semantics
    more convenient for using this struct as a data field of application
    class
 */
struct BlogPosts
{
    import vibe.inet.path : Path;
    import std.algorithm : sort, map;

    private:

        Cache!BlogPost cache;
        immutable(BlogPost)*[] by_date;

    public:

        /// Returns: URL to BlogPost AA
        auto posts_by_url() @property
        {
            return this.cache.entries;
        }

        /// Returns: array of BlogPost, ordered by date
        auto posts_by_date() @property
        {
            return this.by_date;
        }

        /**
            Rebuilds cache with additional entry added

            This is very expensive operation with heavy GC usage. Mood
            is written with assumption that adding new posts is extremely
            rare compared to handling them to readers and thus cache is
            optimized for a very cheap concurrent reading

            Params:
                key = relative path/url for `data`
                data = Markdown sources to be parsed into BlogPost

            Returns:
                this
         */
        ref typeof(this) add(string key, string data) 
        {
            this.cache.replaceWith(this.cache.add(key, data));
            this.reindexCache();
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
            this.reindexCache();
        }

    private:

        /// rebuilds any additional indexes for cache
        void reindexCache()
        {
            this.by_date.length = this.cache.entries.length;
            size_t index = 0;
            foreach (key, ref value; this.cache.entries)
            {
                this.by_date[index] = &value;
                ++index;
            }
            sort!((a, b) => a.created_at > b.created_at)(this.by_date);
        }
}

unittest
{
    import std.datetime : SysTime;

    BlogPosts cache;

    cache.add("/url", "# abcd");
    assert (cache.posts_by_url["/url"].html_full == "<h1> abcd</h1>\n");

    cache.cache.removeAll();
    cache.add("/block/1", "# a");
    cache.add("/block/2", "## b");
    cache.add("/block/3", "### c");

    assert (cache.posts_by_url["/block/1"].html_full == "<h1> a</h1>\n");
    assert (cache.posts_by_url["/block/2"].html_full == "<h2> b</h2>\n");
    assert (cache.posts_by_url["/block/3"].html_full == "<h3> c</h3>\n");

    cache.cache.removeAll();
    auto content ="<!--\nTitle: Some Title\nDate: 20150724T041643.332037\n-->";
    cache.add("/withmeta", content);
    auto post = "/withmeta" in cache.posts_by_url;
    assert (post !is null);
    assert (cache.posts_by_date[0] is post);
    assert (post.title == "Some Title");
    assert (post.created_at == SysTime.fromISOString("20150724T041643.332037"));
    assert (post.md == content);
    assert (post.pretty_date == "2015-Jul-24");
}

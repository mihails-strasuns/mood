/**
    REST API specification suitable for both server and client
 */
module mood.api.spec;

import vibe.web.rest;
import vibe.data.json;
import mood.config;

///
@path("/api/")
interface MoodAPI
{
    /**
        Get original Markdown sources for a given post

        Params:
            _year = 4 digit year part of the URL
            _month = 2 digit month part of the URL
            _title = URL-normalized title

        Returns:
            markdown source of the matching post as string
     */
    @path("posts/:year/:month/:title")
    BlogPost getPost(string _year, string _month, string _title);

    /// ditto
    @path("posts")
    BlogPost getPost(string rel_url);

    /**
        Add new posts to cache, store it in the filesystem and generate
        actual post HTML

        Params:
            title = post title
            content = post Markdown sources (including metadata as HTML comment)
            tags = space-separated tag list

        Returns:
            struct with only member field, `url`, containing relative URL added
            post is available under
    */
    @path("posts")
    PostAddingResult addPost(string title, string content, string tags);

    struct PostAddingResult
    {
        string url;
    }

    /**
        Get last n posts that match (optional) tag.

        Params:
            n = amount of posts to get
            tag = if not empty, only last n posts that match this
                tag are retrieved

        Returns:
            arrays of blog post metadata entries
     */
    @path("posts")
    const(BlogPost)[] getPosts(uint n, string tag = "");
}

// Contains all stored data about single blog post
struct BlogPost
{
    import std.datetime;

    /// Markdown sources for the blog post
    string md;
    /// Post title
    string title;
    /// Array of post tags
    immutable(char[])[] tags;
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
        a simple human-readable form (with a month as a shortened word)

        Returns:
            formatted date string for insertion into rendered pages
     */
    string pretty_date() const @property
    {
        return (cast(Date) this.created_at).toSimpleString();
    }

    /**
        Keeps only month/year part of creation timestamp and formats it in
        a simple human-readable form (with a month as a full word)

        Returns:
            formatted date string for insertion into rendered pages
     */
    string pretty_month() const @property
    {
        import std.string : format;

        string month_word = () {
            final switch (this.created_at.month)
            {
                case Month.jan: return "January";
                case Month.feb: return "February";
                case Month.mar: return "March";
                case Month.apr: return "April";
                case Month.may: return "May";
                case Month.jun: return "June";
                case Month.jul: return "July";
                case Month.aug: return "August";
                case Month.sep: return "September";
                case Month.oct: return "October";
                case Month.nov: return "November";
                case Month.dec: return "December";
            }
        } ();

        return format(
            "%s %s",
            this.created_at.year,
            month_word
        );
    }
}

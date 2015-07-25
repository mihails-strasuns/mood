/**
    REST API implementation
 */
module mood.api.implementation;

import mood.api.spec;

///
class MoodAPI : mood.api.spec.MoodAPI
{
    import mood.cache.posts;

    private BlogPosts* cache;

    ///
    this (ref BlogPosts cache)
    {
        this.cache = &cache;
    }

    override:

        /**
            Get original Markdown sources for a given post

            Params:
                _year = 4 digit year part of the URL
                _month = 2 digit month part of the URL
                _title = URL-normalized title

            Returns:
                markdown source of the matching post as string

            Throws:
                HTTPStatusException (with status NotFound) if requested post
                is not found in cache
        */
        string getPostSource(string _year, string _month, string _title)
        {
            import std.format : format;
            import vibe.http.common;

            auto url = format("%s/%s/%s", _year, _month, _title);
            auto content = url in this.cache.posts_by_url;
            if (content is null)
                throw new HTTPStatusException(HTTPStatus.NotFound);
            return (*content).md;
        }

        /**
            Add new posts to cache, store it in the filesystem and generate
            actual post HTML

            Params:
                raw_title = post title (spaces will be encoded as "_" in the URL)
                content = post Markdown sources (including metadata as HTML comment)

            Returns:
                struct with only member field, `url`, containing relative URL added
                post is available under

            Throws:
                Exception if post with such url/path is already present
        */
        PostAddingResult addPost(string raw_title, string content)
        {
            import mood.config;

            import vibe.inet.path;
            import vibe.core.file;

            import std.array : replace;
            import std.datetime : Clock, SysTime;
            import std.format : format;
            import std.string : strip;
            import std.exception : enforce;

            string title = raw_title
                .replace(" ", "_")
                .strip();

            auto date = Clock.currTime();
            auto prefix = format(
                "%04d/%02d",
                date.year,
                date.month,
            );
            auto target_dir = Path(MoodPathConfig.markdownSources ~ prefix);

            createDirectoryRecursive(target_dir);

            auto file = target_dir ~ Path(title ~ ".md");
            enforce (!existsFile(file));

            string markdown = format(
                "<!--\nTitle: %s\nDate: %s\n-->\n%s",
                raw_title,
                date.toISOString(),
                content
            );

            writeFileUTF8(file, markdown);

            auto url = prefix ~ "/" ~ title;
            this.cache.add(url, markdown);

            return PostAddingResult(url);
        }
}

import vibe.core.log;
import vibe.core.file;
import vibe.inet.path;

// simple utility wrapper missing in vibe.d
// differs from Phobos version by using vibe.d async I/O primitives
private void createDirectoryRecursive(Path path)
{
    if (!existsFile(path))
    {
        createDirectoryRecursive(path.parentPath);
        createDirectory(path);
    }
}

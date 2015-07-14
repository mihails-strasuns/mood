/**
    REST API implementation
 */
module mood.api.implementation;

import mood.api.spec;

///
class MoodAPI : mood.api.spec.MoodAPI
{
    import vibe.http.common;
    import vibe.data.json;

    import mood.cache.posts;
    import mood.config;

    private
    {
        BlogPosts*   cache;
        char[]       buffer;
    }

    this (ref BlogPosts cache)
    {
        this.cache = &cache;
    }

    override:

        string getPostSource(string _year, string _month, string _title)
        {
            // poor man's `format`, don't want to allocate new string each time
            // TODO: fix Phobos formattedWrite
            this.buffer.length = 0;
            assumeSafeAppend(this.buffer);
            this.buffer ~= _year;
            this.buffer ~= "/";
            this.buffer ~= _month;
            this.buffer ~= "/";
            this.buffer ~= _title;

            auto content = buffer in this.cache.posts_by_url;
            if (content is null)
                throw new HTTPStatusException(HTTPStatus.NotFound);
            return (*content).md;
        }

        PostAddingResult addPost(string title, string content)
        {
            import std.regex;
            import std.datetime;
            import std.format;
            import std.string;

            import vibe.inet.path;
            import vibe.core.file;

            static title_transform = ctRegex!(r"\W+");
            static title_trim      = ctRegex!(r"^_*(.*?)_*$");

            string processed_title = title
                .replaceAll(title_transform, "_")
                .replaceAll(title_trim, "$1");

            auto date = Clock.currTime();
            auto prefix = format(
                "%04d/%02d",
                date.year,
                date.month,
            );
            auto target_dir = Path(MoodPathConfig.markdownSources ~ prefix);

            createDirectoryRecursive(target_dir);

            auto file = target_dir ~ Path(processed_title ~ ".md");
            enforce (!existsFile(file));

            string markdown = title ~ "\n==========\n\n" ~ content;
            writeFileUTF8(file, markdown);

            auto url = prefix ~ "/" ~ processed_title;
            this.cache.add(url, markdown);

            return PostAddingResult(url);
        }
}

import vibe.core.log;
import vibe.core.file;
import vibe.inet.path;

private void createDirectoryRecursive(Path path)
{
    if (!existsFile(path))
    {
        createDirectoryRecursive(path.parentPath);
        createDirectory(path);
    }
}

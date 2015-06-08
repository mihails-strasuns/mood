/**
    REST API implementation
 */
module mood.api.implementation;

import mood.api.spec;

///
class MoodAPI : mood.api.spec.MoodAPI
{
    import std.array : appender;

    import vibe.http.common;

    import mood.cache.md;
    import mood.cache.html;

    private
    {
        MarkdownCache*   md;
        HTMLCache*       html;
        char[]           buffer;
    }

    this (ref MarkdownCache md, ref HTMLCache html)
    {
        this.md = &md;
        this.html = &html;
    }

    override:

        string getPostSource(string _year, string _month, string _day, string _title)
        {
            // poor man's `format`, don't want to allocate new string each time
            // TODO: fix Phobos formattedWrite
            this.buffer.length = 0;
            this.buffer ~= _year;
            this.buffer ~= "/";
            this.buffer ~= _month;
            this.buffer ~= "/";
            this.buffer ~= _day;
            this.buffer ~= "/";
            this.buffer ~= _title;

            auto content = buffer in this.md.posts_by_url;
            if (content is null)
                throw new HTTPStatusException(HTTPStatus.NotFound);
            return *content;
        }
}

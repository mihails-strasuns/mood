/**
    Encapsulates knowledge of RSS layout and converts processed
    request data into appropriated rendered XML
 */
module mood.rendering.rss;

import mood.api.spec;

import vibe.http.server;

/**
    Renders RSS post feed

    Params:
        output = stream to write xml to
        posts = main blog post feed
 */
void renderFeed(typeof(HTTPServerResponse.bodyWriter) output, const BlogPost[] posts)
{
    import std.string : format;

    string base_url = "INSERT-YOUR-URL";

    string genItem(const BlogPost post)
    {
        return format(
            "<item><title>%s</title><link>%s</link><pubDate>%s</pubDate></item>\n",
            post.title,
            base_url ~ "/" ~ post.relative_url,
            post.created_at.toISOString()
        );
    }

    import std.algorithm : map;
    import std.range : join;
    auto feed = posts.map!genItem.join();

    auto xml = format(
        // feed data
        "<?xml version='1.0' encoding='UTF-8' ?><rss version='2.0'>\n"
            ~ "<channel>\n<title>INSERT-YOUR-TITLE</title>\n"
            ~ "<link>%s</link>\n%s</channel>\n</rss>",
        base_url,
        feed
    );

    output.write(xml);
}

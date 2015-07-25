/**
    REST API specification suitable for both server and client
 */
module mood.api.spec;

import vibe.web.rest;
import vibe.data.json;
import mood.config;

///
@rootPath("/api/")
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
    @path("posts/sources/:year/:month/:title")
    string getPostSource(string _year, string _month, string _title);

    struct PostAddingResult
    {
        string url;
    }

    /**
        Add new posts to cache, store it in the filesystem and generate
        actual post HTML

        Params:
            title = post title
            content = post Markdown sources (including metadata as HTML comment)

        Returns:
            struct with only member field, `url`, containing relative URL added
            post is available under
    */
    @path("posts")
    PostAddingResult addPost(string title, string content);
}

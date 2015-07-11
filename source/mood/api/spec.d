/**
    REST API specification suitable for both server and client
 */
module mood.api.spec;

import vibe.web.rest;
import vibe.data.json;
import mood.config;

///
@rootPath(MoodURLConfig.apiBase)
interface MoodAPI
{
    /**
     */
    @path("posts/sources/:year/:month/:title")
    string getPostSource(string _year, string _month, string _title);

    struct PostAddingResult
    {
        string url;
    }

    @path("posts")
    PostAddingResult addPost(string title, string content);
}

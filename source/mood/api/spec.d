/**
    REST API specification suitable for both server and client
 */
module mood.api.spec;

import vibe.web.rest;
import mood.config;

///
@rootPath(MoodURLConfig.apiBase)
interface MoodAPI
{
    /**
     */
    @path("posts/sources/:year/:month/:day/:title")
    string getPostSource(string _year, string _month, string _day, string _title);
}

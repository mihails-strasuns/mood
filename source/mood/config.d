/**
    Defines application-wide constants in one easy to tweak place
 */
module mood.config;

/**
    Configuration for filesystem paths
 */
enum MoodPathConfig
{
    statics         = "./static/",
    markdownSources = "./generated/md/",
    articleHTML     = "./generated/html/",
}

/**
    Configuration for URL paths
 */
enum MoodURLConfig
{
    apiBase = "/api/",
    posts   = "/posts/*",
}

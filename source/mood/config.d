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
    certificates    = "./certs/",
}

/**
    Configuration for URL paths
 */
enum MoodURLConfig
{
    apiBase = "/api/",
    posts   = "/posts",
    admin   = "/admin",
}

/**
    Used to identify blog owner
 */
enum MoodAuthConfig
{
    user     = "please don't store me in git",
    password = "please don't store me in git",
    realm    = "please don't store me in git"
}

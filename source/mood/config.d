/**
    Defines application-wide constants in one easy to tweak place
    dfdsf
 */
module mood.config;

/**
    Configuration for filesystem paths

    All entries must end with '/' for uniform appending in the app
 */
enum MoodPathConfig
{
    statics         = "./static/",
    markdownSources = "./generated/md/",
    articleHTML     = "./generated/html/",
    certificates    = "./certs/",
}

/**
    Used to tweak various rendering options
 */
enum MoodViewConfig
{
    // how many blog post links to display in side panel
    sidePanelSize = 10,
}

/**
    Used to identify blog owner
 */
enum MoodAuthConfig
{
    user     = "please don't store me in git",
    password = "please don't store me in git",
    realm    = "please don't store me in git",
}

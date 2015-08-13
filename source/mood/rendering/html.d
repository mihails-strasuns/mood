/**
    Encapsulates knowledge of HTML templates and converts processed
    request data into appropriated rendered web page
 */
module mood.rendering.html;

import mood.api.spec;

import vibe.core.stream;
import vibe.templ.diet;

/**
    Renders index page with a post feed
    
    Params:
        output = stream to write rendered html to
        posts = main blog post feed
        last_posts = list of last posts to display links to in side block
 */
void renderIndex(OutputStream output, const BlogPost[] posts,
    const BlogPost[] last_posts)
{
    parseDietFile!("pages/index.dt", posts, last_posts)(output);
}

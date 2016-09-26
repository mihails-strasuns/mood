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
    compileDietFile!("pages/index.dt", posts, last_posts)(output);
}

/**
    Renders page with full content for a specific blog post

    Params:
        output = stream to write rendered html to
        post = the one
        last_posts = list of last posts to display links to in side block
 */
void renderSinglePost(OutputStream output, const ref BlogPost post,
    const BlogPost[] last_posts)
{
    compileDietFile!("pages/single_post.dt", post, last_posts)(output);
}

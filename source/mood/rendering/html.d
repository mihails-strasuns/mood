/**
    Encapsulates knowledge of HTML templates and converts processed
    request data into appropriated rendered web page
 */
module mood.rendering.html;

import mood.api.spec;

import vibe.http.server;
import vibe.stream.wrapper;
import diet.html;

/**
    Renders index page with a post feed

    Params:
        output = stream to write rendered html to
        posts = main blog post feed
        last_posts = list of last posts to display links to in side block
 */
void renderIndex(typeof(HTTPServerResponse.bodyWriter) output,
    const BlogPost[] posts, const BlogPost[] last_posts)
{
    auto or = streamOutputRange(output);
    or.compileHTMLDietFile!("pages/index.dt", posts, last_posts);
}

/**
    Renders page with full content for a specific blog post

    Params:
        output = stream to write rendered html to
        post = the one
        last_posts = list of last posts to display links to in side block
 */
void renderSinglePost(typeof(HTTPServerResponse.bodyWriter) output,
    const ref BlogPost post, const BlogPost[] last_posts)
{
    auto or = streamOutputRange(output);
    or.compileHTMLDietFile!("pages/single_post.dt", post, last_posts);
}

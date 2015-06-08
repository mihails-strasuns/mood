module test.cache;

import test.env : rootDir;

import mood.cache.md;
import mood.cache.html;

unittest
{
    import std.file;
    import vibe.inet.path;

    // env preparation

    string test_dir = rootDir ~ "cache.md/";
    mkdir(test_dir);
    mkdirRecurse(test_dir ~ "url1/nested");
    write(test_dir ~ "url1/nested/" ~ "article.md", "# a");
    write(test_dir ~ "url1/nested/" ~ "article.dm", "# a");
    mkdirRecurse(test_dir ~ "url2");
    write(test_dir ~ "url2/" ~ "article.md", "### x");
    mkdirRecurse(test_dir ~ "url3");

    // tests

    HTMLCache html;
    auto md = MarkdownCache(html);
    md.loadFromDisk(Path(test_dir));

    assert (md.posts_by_url["url1/nested/article"] == "# a");
    assert (md.posts_by_url["url2/article"] == "### x");
    assert (md.posts_by_url.length == 2);

    assert (html.posts_by_url["url1/nested/article"] == "<h1> a</h1>\n");
    assert (html.posts_by_url["url2/article"] == "<h3> x</h3>\n");
    assert (html.posts_by_url.length == 2);
}

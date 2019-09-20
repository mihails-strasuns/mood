module test.cache;

import test.env : rootDir;

import mood.storage.posts;

unittest
{
    import std.file;
    import std.path;
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

    // most common workflow

    BlogPostStorage cache;
    cache.loadFromDisk(NativePath(test_dir));

    assert (cache.posts_by_url["url1/nested/article"].md == "# a");
    assert (cache.posts_by_url["url1/nested/article"].html_full == "<h1> a</h1>\n");
    assert (cache.posts_by_url["url2/article"].md == "### x");
    assert (cache.posts_by_url["url2/article"].html_full == "<h3> x</h3>\n");
    assert (cache.posts_by_url.length == 2);

    // missing cache dump on disk

    cache.loadFromDisk(NativePath("/unlikely/to/exist"));
    assert (cache.posts_by_url.length == 0);

    // relative base path

    auto relpath = NativePath(relativePath(test_dir, getcwd()));
    cache.loadFromDisk(relpath);
    assert (cache.posts_by_url.length == 2);
}

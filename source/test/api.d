module test.api;

import test.env : rootDir;

import mood.api.implementation;
import mood.cache.posts;

import vibe.http.common;
import std.datetime;
import std.string;
import std.conv;
import std.file;

unittest
{
    string test_dir = rootDir ~ "api.md/";
    mkdirRecurse(test_dir);
    chdir(test_dir);
    scope(exit)
        chdir(rootDir);

    // tested objects
    BlogPosts cache;
    auto api = new MoodAPI;

    // tests
    try
    {
        api.getPost("0000", "00", "title");
        assert (false);
    }
    catch (HTTPStatusException e)
    {
        assert (e.status == HTTPStatus.NotFound);
    }

    auto date = Clock.currTime();
    auto year = format("%04d", date.year);
    auto month = format("%02d", date.month);
    auto expected_url = format("%s/%s/some_title", year, month);

    auto ret = api.addPost("some title", "content");
    assert (ret.url == expected_url);

    auto entry = api.getPost(year, month, "some_title");
    // avoid figuring out exact timestamp stored
    import std.regex;
    auto md = entry.md.replaceAll(regex(r"Date: .+"), "XXX");
    assert (md == "<!--\nTitle: some title\nXXX\n-->\ncontent");
}

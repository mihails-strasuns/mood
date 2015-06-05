module api;

import std.regex;
import std.datetime;
import std.format;
import std.string;

import vibe.inet.path;
import vibe.core.log;
import vibe.core.file;
import vibe.web.rest;
import vibe.data.json;

import types;
import util;

auto slugRegex = regex(r"\W+");
auto slugTrimRegex = regex(r"^_*(.*?)_*$");

interface IAPI
{
    Json addPost(string title, string content);
}

class API : IAPI
{
    Settings settings;

    this(Settings settings)
    {
        this.settings = settings;
    }

    Json addPost(string title, string content)
    {
        string slug = replaceAll(replaceAll(title, slugRegex, "_"), slugTrimRegex,
            "$1");

        auto st = Clock.currTime();
        auto datestr = format("%04d/%02d/%02d", st.year, st.month, st.day);
        auto dir = settings.path ~ Path("markdown") ~ Path(datestr);

        createDirectoryRecursive(dir);

        auto file = dir ~ Path(slug ~ ".md");
        auto i = 2;
        while (existsFile(file))
        {
            file = dir ~ Path(slug ~ "_" ~ to!string(i++) ~ ".md");
        }

        string markdown = title ~ "\n==========\n\n" ~ content;

        writeFileUTF8(file, markdown);

        Json ret = Json.emptyObject;
        ret["url"] = "/" ~ datestr ~ "/" ~ slug ~ ".html";
        return ret;
    }
}

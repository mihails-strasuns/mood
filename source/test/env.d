module test.env;

import std.file;

string rootDir;

shared static this ()
{
    rootDir = getcwd() ~ "/sandbox/";
    mkdirRecurse(rootDir);
}

shared static ~this ()
{
    rmdirRecurse(rootDir);
}

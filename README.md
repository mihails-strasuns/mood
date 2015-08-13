# MOOD
KISS blog implementation in D tuned for programmers

Based on http://vibed.org

## Goals / Features

1. stand-alone binary with minimal external dependencies
2. simple deployment under dedicated posix user
3. straightforward code, minimal to none configurability - fork instead
4. basic features include publishing posts, tags and RESTful API for data model
5. with `-version=MoodWithPygmentize` does out of the box code highlighting if `pygmentize` is on `$PATH`
6. no JavaScript
7. HTTPS-only
8. no database needed, articles can be edited as simple Markdown files

## Running

1. fork this repository
2. modify `main.d` to use valid paths to SSL certificates
3. (optional) tweak Diet templates / CSS / code as you see fit
4. `dub build` (optionally enable `MoodWithPygmentize` version in project file)
5. `dub run`
6. (optional/recommended) modify `nginx.include` to use valid domain name / certificates and include it into your `nginx.conf`

## Architecture

`mood.storage` implements in-memory immutable cache for post data. It saves new posts to
the filesystem in a hard-coded layout and reloads them when mood process starts.

`mood.api` defines data model used by rest of the application. It is exposed via RESTful
API thus allowing any custom client programs to fetch the data from blog. This is the only
part of Mood that has direct access to `mood.storage`.

`mood.rendering` contains set of functions that build data representation in requested format
based on supplied arguments. Naturally, HTML page rendering (both live and offline) is the main
part.

`mood.util` contains various tools that author found missing in vibe.d while writing this project.

`mood.config` defines some funamental hard-coded configuration options like administrator password
or filesystem paths used. Everything else is configured by simply changing the code.

`mood.application` is the entry point for all web page routes. It uses `mood.api` to get the blog data
and `mood.rendering` to actually build the response.

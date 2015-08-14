<!--
Title: In the mood for some releasing
Date: 20150814T233007.417923
Tags: code
-->

TL; DR: [https://github.com/Dicebot/mood](https://github.com/Dicebot/mood)

Lack of self-hosted blog platform that could suit my preferences has been
bothering me for a while. Pretty much everything open-sourced out there was
some PHP monstrosity that would require you to spend half a day configuring
application server and SQL database to just get started. All to get half a
second load times for single user for something that is effectively a static
HTML page.

Purely static generators seemed to work much better but I wanted a bit more
power and flexibility. What if eventually I want to add comment support? Or
anything else dynamic? In the end I decided to have finally write some D
project purely for fun, something I haven't done for ages.

That is how [mood](https://github.com/Dicebot/mood) was born. Several evenings
worth of spare time and poking fellow web developer to create a simple design
and I got the thing working - at least good enough to power this specific blog
:)

### Goals

This is short goal/feature list copied from project README:

- stand-alone binary with minimal external dependencies
- simple deployment under dedicated posix user
- straightforward code, minimal to none configurability - fork instead
- basic features include publishing posts, tags and RESTful API for data model
- with -version=MoodWithPygmentize does out of the box code highlighting if pygmentize is on $PATH
- no JavaScript
- HTTPS-only
- no database needed, articles can be edited as simple Markdown files

Some points (like HTTPS enforcement) can be rather controversial but I tried to
stick with decisions that are safe and simple by default even if causes some
unnecessary overhead.  For example, this HTTPS-only approach allowed me to use
basic auth without being worried that someone will accidentally host mood-based
blog with protected paths available via plain HTTP.

Originally I wanted this to be a library providing building blocks for hacking
own blog implementation quickly from scratch. But quickly realized that I have
very vague idea of what convenient API could look like or even what feature set
will be needed. So it is kept simple for now and possible librarization is
reserved for [next major version](https://github.com/Dicebot/mood/milestones)

### Work-In-Progress

Despite there is currently 1.0.0 release tagged, mood remains heavily
work-in-progress. This release means simply that it is good enough for small
personal blog no one visits and I can actually start adding new posts there.
There are still quite some [issues](https://github.com/Dicebot/mood/issues),
most importantly performance one - while pages load almost instantly, server is
capable of handling only about 4000 request per second on my machine and leaks
about 100Mb per 100000 requests.

Which is not that bad considering I have not bothered with any efficiency at
all, but still hurts my ego. Will need to be taken care of eventually.

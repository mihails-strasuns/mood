/**
    REST API implementation
 */
module mood.api.implementation;

import mood.api.spec;
import vibe.core.log;

public import mood.api.spec : BlogPost;

///
class MoodAPI : mood.api.spec.MoodAPI
{
    import mood.config;
    import mood.storage.posts;

    private BlogPostStorage storage;

    ///
    this ()
    {
        version (unittest) { /* use empty data set for tests */ }
        {
            logInfo("Preparing blog post data");

            auto markdown_sources = Path(MoodPathConfig.markdownSources);
            logInfo("Looking for blog post sources at %s", markdown_sources);
            this.storage.loadFromDisk(markdown_sources);
            logInfo("%s posts loaded", this.storage.posts_by_url.length);
            import std.range : join;
            logTrace("\t%s", this.storage.posts_by_url.keys.join("\n\t"));
        }
    }

    override:

        /**
            Get original Markdown sources for a given post

            Params:
                _year = 4 digit year part of the URL
                _month = 2 digit month part of the URL
                _title = URL-normalized title

            Returns:
                markdown source of the matching post as string

            Throws:
                HTTPStatusException (with status NotFound) if requested post
                is not found in storage
        */
        BlogPost getPost(string _year, string _month, string _title)
        {
            static if(__VERSION__>2066L)
                import std.format : format;
            else
                import std.string : format;
            import vibe.http.common;

            auto url = format("%s/%s/%s", _year, _month, _title);
            return this.getPost(url);
        }

        /// ditto
        BlogPost getPost(string rel_url)
        {
            import vibe.http.common;

            auto content = rel_url in this.storage.posts_by_url;
            if (content is null)
                throw new HTTPStatusException(HTTPStatus.NotFound);
            return (*content).metadata;
        }

        /**
            Add new posts to storage, store it in the filesystem and generate
            actual post HTML

            Params:
                raw_title = post title (spaces will be encoded as "_" in the URL)
                content = post Markdown sources (including metadata as HTML comment)
                tags = space-separated tag list

            Returns:
                struct with only member field, `url`, containing relative URL added
                post is available under

            Throws:
                Exception if post with such url/path is already present
        */
        PostAddingResult addPost(string raw_title, string content, string tags)
        {
            import mood.config;

            import vibe.inet.path;
            import vibe.core.file;

            import std.array : replace;
            import std.datetime : Clock, SysTime;
            static if (__VERSION__ < 2067L)
            {
                import std.string:format;
            }
            else
            {
                import std.format : format;
                import std.string: lineSplitter;
            }
            import std.string : strip, join;
            import std.exception : enforce;

            // normalize line endings to posix ones
            content = content.lineSplitter.join("\n");

            string title = raw_title
                .replace(" ", "_")
                .strip();

            auto date = Clock.currTime();
            auto prefix = format(
                "%04d/%02d",
                date.year,
                date.month,
            );
            auto target_dir = Path(MoodPathConfig.markdownSources ~ prefix);

            createDirectoryRecursive(target_dir);

            auto file = target_dir ~ Path(title ~ ".md");
            enforce (!existsFile(file));

            string markdown = format(
                "<!--\nTitle: %s\nDate: %s\nTags: %s\n-->\n%s",
                raw_title,
                date.toISOString(),
                tags,
                content
            );

            writeFileUTF8(file, markdown);

            auto url = prefix ~ "/" ~ title;
            this.storage.add(url, markdown);

            return PostAddingResult(url);
        }

        /**
            Get last n posts that match (optional) tag.

            Params:
                n = amount of posts to get
                tag = if not empty, only last n posts that match this
                    tag are retrieved

            Returns:
                arrays of blog post metadata entries
         */
        const(BlogPost)[] getPosts(uint n, string tag = "")
        {
            import std.algorithm : filter, map;
            import std.range : take;
            import std.array : array;

            // predicate to check if specific blog posts has required tag
            // always 'true' if there is no tag filter defined
            bool hasTag(const CachedBlogPost* post)
            {
                if (tag.length == 0)
                    return true;

                foreach (post_tag; post.tags)
                {
                    if (post_tag == tag)
                        return true;
                }

                return false;
            }

            return this.storage.posts_by_date
                .filter!hasTag
                .take(n)
                .map!(x => x.metadata)
                .array;
        }

    // end of `override:`
}

import vibe.core.log;
import vibe.core.file;
import vibe.inet.path;

// simple utility wrapper missing in vibe.d
// differs from Phobos version by using vibe.d async I/O primitives
private void createDirectoryRecursive(Path path)
{
    if (!existsFile(path))
    {
        createDirectoryRecursive(path.parentPath);
        createDirectory(path);
    }
}

static if (__VERSION__ <2067L)
{
    import std.string;
    import std.range;
    import std.algorithm;
        auto lineSplitter(KeepTerminator keepTerm = KeepTerminator.no, Range)(Range r)
    if ((hasSlicing!Range && hasLength!Range) ||
        isSomeString!Range)
    {
        import std.uni : lineSep, paraSep;
        import std.conv : unsigned;

        static struct Result
        {
        private:
            Range _input;
            alias IndexType = typeof(unsigned(_input.length));
            enum IndexType _unComputed = IndexType.max;
            IndexType iStart = _unComputed;
            IndexType iEnd = 0;
            IndexType iNext = 0;

        public:
            this(Range input)
            {
                _input = input;
            }

            static if (isInfinite!Range)
            {
                enum bool empty = false;
            }
            else
            {
                @property bool empty()
                {
                    return iStart == _unComputed && iNext == _input.length;
                }
            }

            @property Range front()
            {
                if (iStart == _unComputed)
                {
                    iStart = iNext;
                  Loop:
                    for (IndexType i = iNext; ; ++i)
                    {
                        if (i == _input.length)
                        {
                            iEnd = i;
                            iNext = i;
                            break Loop;
                        }
                        switch (_input[i])
                        {
                            case '\v', '\f', '\n':
                                iEnd = i + (keepTerm == KeepTerminator.yes);
                                iNext = i + 1;
                                break Loop;

                            case '\r':
                                if (i + 1 < _input.length && _input[i + 1] == '\n')
                                {
                                    iEnd = i + (keepTerm == KeepTerminator.yes) * 2;
                                    iNext = i + 2;
                                    break Loop;
                                }
                                else
                                {
                                    goto case '\n';
                                }

                            static if (_input[i].sizeof == 1)
                            {
                                /* Manually decode:
                                 *  lineSep is E2 80 A8
                                 *  paraSep is E2 80 A9
                                 */
                                case 0xE2:
                                    if (i + 2 < _input.length &&
                                        _input[i + 1] == 0x80 &&
                                        (_input[i + 2] == 0xA8 || _input[i + 2] == 0xA9)
                                       )
                                    {
                                        iEnd = i + (keepTerm == KeepTerminator.yes) * 3;
                                        iNext = i + 3;
                                        break Loop;
                                    }
                                    else
                                        goto default;
                                /* Manually decode:
                                *  NEL is C2 85
                                */
                                case 0xC2:
                                    if(i + 1 < _input.length && _input[i + 1] == 0x85)
                                    {
                                        iEnd = i + (keepTerm == KeepTerminator.yes) * 2;
                                        iNext = i + 2;
                                        break Loop;
                                    }
                                    else
                                        goto default;
                            }
                            else
                            {
                                case '\u0085':
                                case lineSep:
                                case paraSep:
                                    goto case '\n';
                            }

                            default:
                                break;
                        }
                    }
                }
                return _input[iStart .. iEnd];
            }

            void popFront()
            {
                if (iStart == _unComputed)
                {
                    assert(!empty);
                    front();
                }
                iStart = _unComputed;
            }

            static if (isForwardRange!Range)
            {
                @property typeof(this) save()
                {
                    auto ret = this;
                    ret._input = _input.save;
                    return ret;
                }
            }
        }

        return Result(r);
    }
}
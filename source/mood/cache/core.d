/**
    Basic content-agnostic cache implementation
 */
module mood.cache.core;

/**
    Cache is defined as shared pointer to immutable cache data. When cache
    needs to be updated, whole new immutable data set gets built and pointer
    to "current" cache gets updated with an atomic operation.

    This relies on the fact that posts are changed rarely but served often
    and allows no-lock implicit sharing of cache between worker threads.
 */
struct Cache
{
    /// pointer to latest cached content
    shared immutable(CacheData)* data = new CacheData;
    alias data this;

    /// Updates cache pointer in a thread-safe manner
    void replaceWith(Cache new_cache)
    {
        this.replaceWith(new_cache.data);
    }

    /// ditto
    void replaceWith(immutable(CacheData)* new_data)
    {
        import core.atomic;
        atomicStore(this.data, new_data);
    }
}

///
unittest
{
    Cache cache;

    // empty cache by default
    assert (cache.posts_by_url.length == 0);

    // can't modify data directly, immutable
    static assert (!__traits(compiles, { cache.posts_by_url["key"] = "data"; }));

    // can build a new immutable cache instead
    auto new_cache = cache.add("key", "data1");
    new_cache      = cache.add("key", "data2");
    assert (new_cache.posts_by_url["key"] == "data2");

    // and replace old reference (uses be atomic operation)
    cache.replaceWith(new_cache);
    assert (cache.posts_by_url["key"] == "data2");
}

/**
    Core cache payload implementation.

    Supposed to be used via `Cache` alias.
 */
struct CacheData
{
    import vibe.inet.path : Path;

    /// Mapping of relative URL (also relative file path on disk) to raw data
    string[string] posts_by_url;

    /**
        Builds new immutable cache with additional entry added

        Params:
            key = relative URL of the post this must be used as source for
            data = markdown content used as that post source

        Returns:
            pointer to new immtable cache built on top of this one
     */
    Cache add(string key, string data) immutable
    {
        auto cache = new CacheData;
        foreach (old_key, old_data; this.posts_by_url)
            cache.posts_by_url[old_key] = old_data;
        cache.posts_by_url[key] = data;

        return Cache(assumePayloadUnique(cache));
    }

    /**
        Initializes cache from disk

        NB! This method uses blocking file I/O and should be called before
        starting main application event loop.

        Params:
            root_path = directory path for all markdown sources. Keys in the
                cache will be calculated as file paths relative to root_path
            ext = extension of files to load. Will be removed from the URL.
                If empty, all files will be loaded as-is

        Returns:
            pointer to immutable cache filled with data
     */
    static Cache loadFromDisk(Path root_path, string ext)
    {
        import std.file;
        import std.path : relativePath;
        import std.algorithm : endsWith;

        auto root = root_path.toString();
        if (root.length == 0)
            return Cache(null);

        auto cache = new CacheData;

        foreach (DirEntry path; dirEntries(root, SpanMode.depth))
        {
            if (path.isFile && path.name.endsWith(ext))
            {
                auto key = relativePath(path.name, root)[0 .. $ - ext.length];
                cache.posts_by_url[key] = readText(path.name);
            }
        }

        return Cache(assumePayloadUnique(cache));
    }
}

/*
    Can't use assumeUnique in cases when only tail is immutable, not pointer
    itself.

    Params:
        ptr = pointer to data in shared memory that doesn't have any other
            references to at the moment

    Returns:
        same pointer but with payload considered immutable
 */
private auto assumePayloadUnique(T)(T* ptr)
{
    return cast(immutable(T)*) ptr;
}

///
unittest
{
    auto ptr1 = cast(int*) 0x42;
    auto ptr2 = assumePayloadUnique(ptr1);
    assert (ptr2 is ptr1);
    static assert (is(typeof(ptr2) == immutable(int)*));
}

/**
    Small helper based on static reflection to gather route data
    from handler method attribute and do automatic route registration
    based one that.

    Intended as a solution to keep request handler information as packed
    in one place as possible for improved maintenance.

    Evnetually should be replaced with vibe.d native utilities
 */
module mood.util.route_attr;

import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.web.common;

/**
    Finds all methods of class T that have `@path` attribute attached
    and registers them in router either for all HTTP methods (default)
    or for a HTTP method specified by `@method` attribute.

    Any method that has `@auth` attribute will also have `auth_dg`
    handler registered for relevant path before normal request handler.
    Such auth delegate is supposed to issue HTTP error response in case
    of failed auth thus terminating further route resolving process.

    Params:
        router = URLRouter to register handlers in
        app = any user class object with methods that need to be
            registered as HTTP handlers
        auth_dg = HTTP request handler that performs the authentication
            and issues HTTP error response if it fails
 */
void register(T)(URLRouter router, T app,
        void delegate(HTTPServerRequest, HTTPServerResponse) auth_dg = null)
    if (is(T == class))
{
    import vibe.web.common;

    import vibe.internal.meta.uda : findFirstUDA;

    foreach (method_name; __traits(allMembers, T))
    {
        // second condition ensures symbols is really a field/method and
        // not an alias/module/dragon
        static if (isUserMethod(method_name)
            && is(typeof(__traits(getMember, app, method_name))))
        {
            mixin("alias method    = app." ~ method_name ~ ";");
            mixin("auto  method_dg = &app." ~ method_name ~ ";");

            enum http = findFirstUDA!(MethodAttribute, method);
            enum path = findFirstUDA!(PathAttribute, method);
            enum auth = findFirstUDA!(AuthRequirementAttribute, method);

            static if (auth.found)
                assert (auth_dg !is null);

            // methods without @path attribute are skipped
            static if (path.found)
            {
                static assert(is(typeof(method_dg)
                    == void delegate(HTTPServerRequest, HTTPServerResponse)));

                static if (http.found)
                {
                    switch (http.value.data)
                    {
                        case HTTPMethod.GET:
                            static if (auth.found) router.get(path.value, auth_dg);
                            router.get(path.value, method_dg);
                            break;
                        case HTTPMethod.POST:
                            static if (auth.found) router.post(path.value, auth_dg);
                            router.post(path.value, method_dg);
                            break;
                        case HTTPMethod.DELETE:
                            static if (auth.found) router.delete_(path.value, auth_dg);
                            router.delete_(path.value, method_dg);
                            break;
                        case HTTPMethod.PATCH:
                            static if (auth.found) router.patch(path.value, auth_dg);
                            router.patch(path.value, method_dg);
                            break;
                        case HTTPMethod.PUT:
                            static if (auth.found) router.put(path.value, auth_dg);
                            router.put(path.value, method_dg);
                            break;
                        default:
                            assert(false);
                    }
                }
                else
                {
                    static if (auth.found) router.any(path.value, auth_dg);
                    router.any(path.value, method_dg);
                }
            }
        }
    }
}

unittest
{
    // default method (any)
    import vibe.web.common;

    class WebApp
    {
        @path("/something")
        void handler(HTTPServerRequest req, HTTPServerResponse res) { }
    }

    auto app = new WebApp;
    auto router = new URLRouter;
    router.register(app);

    auto routes = router.getAllRoutes();

    import std.traits : EnumMembers;
    import std.conv;

    assert(routes.length == EnumMembers!HTTPMethod.length, to!string(routes.length));
}

unittest
{
    // explicit method + auth
    import vibe.web.common;

    class WebApp
    {
        @path("/42") @method(HTTPMethod.GET) @auth
        void f1(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/43") @method(HTTPMethod.PUT) @auth
        void f2(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/44") @method(HTTPMethod.POST) @auth
        void f3(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/45") @method(HTTPMethod.PATCH) @auth
        void f4(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/46") @method(HTTPMethod.DELETE) @auth
        void f5(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/noauth") @method(HTTPMethod.PUT)
        void f6(HTTPServerRequest req, HTTPServerResponse res) { }
    }

    void auth_handler(HTTPServerRequest, HTTPServerResponse) { }

    auto app = new WebApp;
    auto router = new URLRouter;
    router.register(app, &auth_handler);

    auto routes = router.getAllRoutes();
    assert(routes[0].method == HTTPMethod.GET && routes[0].pattern == "/42");
    assert(routes[1].method == HTTPMethod.GET && routes[1].pattern == "/42");

    assert(routes[2].method == HTTPMethod.PUT && routes[2].pattern == "/43");
    assert(routes[3].method == HTTPMethod.PUT && routes[3].pattern == "/43");

    assert(routes[4].method == HTTPMethod.POST && routes[4].pattern == "/44");
    assert(routes[5].method == HTTPMethod.POST && routes[5].pattern == "/44");

    assert(routes[6].method == HTTPMethod.PATCH && routes[6].pattern == "/45");
    assert(routes[7].method == HTTPMethod.PATCH && routes[7].pattern == "/45");

    assert(routes[8].method == HTTPMethod.DELETE && routes[8].pattern == "/46");
    assert(routes[9].method == HTTPMethod.DELETE && routes[9].pattern == "/46");
}

/**
    "Tag" type, used only as an attribute to indicate necessity to perform auth

    See `mood.util.route_attr.register` for more details.
 */
struct AuthRequirementAttribute { }

/// ditto
AuthRequirementAttribute auth() @property
{
    return AuthRequirementAttribute.init;
}

unittest
{
    assert (auth == AuthRequirementAttribute.init);
}

private:

// used to filter out Object methods, including "magic" methods
// like '__ctor' or 'this'
static bool isUserMethod(string name)
{
    class Empty { }
    import std.algorithm : canFind;
    return !canFind([__traits(allMembers, Empty)], name);
}

unittest
{
    assert ( isUserMethod("aaa"));
    assert (!isUserMethod("this"));
}

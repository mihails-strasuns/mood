module extra.routing;

import vibe.http.router;
import vibe.web.common;

struct AuthRequiredAttribute { }

AuthRequiredAttribute auth() @property
{
    assert (__ctfe);
    return AuthRequiredAttribute.init;
}

void register(T)(URLRouter router, T app,
        void delegate(HTTPServerRequest, HTTPServerResponse) auth_dg)
    if (is(T == class))
{
    static bool isUserMethod(string name)
    {
        class Empty { }
        import std.algorithm : canFind;
        return !canFind([__traits(allMembers, Empty)], name);
    }

    import vibe.internal.meta.uda : findFirstUDA;

    foreach (method_name; __traits(allMembers, T))
    {
        static if (isUserMethod(method_name)
            && is(typeof(__traits(getMember, app, method_name))))
        {
            mixin("alias method    = app." ~ method_name ~ ";");
            mixin("auto  method_dg = &app." ~ method_name ~ ";");

            enum http = findFirstUDA!(MethodAttribute, method);
            enum path = findFirstUDA!(PathAttribute, method);
            enum auth = findFirstUDA!(AuthRequiredAttribute, method);
            pragma(msg, __traits(getAttributes, method));

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
    // explicit method

    class WebApp
    {
        @path("/42") @method(HTTPMethod.GET)
        void f1(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/43") @method(HTTPMethod.PUT)
        void f2(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/44") @method(HTTPMethod.POST)
        void f3(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/45") @method(HTTPMethod.PATCH)
        void f4(HTTPServerRequest req, HTTPServerResponse res) { }

        @path("/46") @method(HTTPMethod.DELETE)
        void f5(HTTPServerRequest req, HTTPServerResponse res) { }
    }

    auto app = new WebApp;
    auto router = new URLRouter;
    router.register(app);

    auto routes = router.getAllRoutes();
    assert(routes[0].method == HTTPMethod.GET && routes[0].pattern == "/42");
    assert(routes[1].method == HTTPMethod.PUT && routes[1].pattern == "/43");
    assert(routes[2].method == HTTPMethod.POST && routes[2].pattern == "/44");
    assert(routes[3].method == HTTPMethod.PATCH && routes[3].pattern == "/45");
    assert(routes[4].method == HTTPMethod.DELETE && routes[4].pattern == "/46");
}

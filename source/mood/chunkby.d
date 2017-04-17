module mood.chunkby;
static if (__VERSION__ <2067L)
{
    // from Phobos - see License
    import std.functional; // : unaryFun, binaryFun;
    import std.range;
    import std.traits;

    private template ChunkByImplIsUnary(alias pred, Range)
    {
        static if (is(typeof(binaryFun!pred(ElementType!Range.init,
                                            ElementType!Range.init)) : bool))
            enum ChunkByImplIsUnary = false;
        else static if (is(typeof(
                unaryFun!pred(ElementType!Range.init) ==
                unaryFun!pred(ElementType!Range.init))))
            enum ChunkByImplIsUnary = true;
        else
            static assert(0, "chunkBy expects either a binary predicate or "~
                             "a unary predicate on range elements of type: "~
                             ElementType!Range.stringof);
    }

    // Implementation of chunkBy for non-forward input ranges.
    private struct ChunkByImpl(alias pred, Range)
        if (isInputRange!Range && !isForwardRange!Range)
    {
        enum bool isUnary = ChunkByImplIsUnary!(pred, Range);

        static if (isUnary)
            alias eq = binaryFun!((a, b) => unaryFun!pred(a) == unaryFun!pred(b));
        else
            alias eq = binaryFun!pred;

        private Range r;
        private ElementType!Range _prev;

        this(Range _r)
        {
            r = _r;
            if (!empty)
            {
                // Check reflexivity if predicate is claimed to be an equivalence
                // relation.
                assert(eq(r.front, r.front),
                       "predicate is not reflexive");

                // _prev's type may be a nested struct, so must be initialized
                // directly in the constructor (cannot call savePred()).
                _prev = r.front;
            }
            else
            {
                // We won't use _prev, but must be initialized.
                _prev = typeof(_prev).init;
            }
        }
        @property bool empty() { return r.empty; }

        @property auto front()
        {
            static if (isUnary)
            {
                import std.typecons : tuple;
                return tuple(unaryFun!pred(_prev),
                             ChunkByChunkImpl!(eq, Range)(r, _prev));
            }
            else
            {
                return ChunkByChunkImpl!(eq, Range)(r, _prev);
            }
        }

        void popFront()
        {
            while (!r.empty)
            {
                if (!eq(_prev, r.front))
                {
                    _prev = r.front;
                    break;
                }
                r.popFront();
            }
        }
    }

    // Single-pass implementation of chunkBy for forward ranges.
    private struct ChunkByImpl(alias pred, Range)
        if (isForwardRange!Range)
    {
        import std.typecons : RefCounted;

        enum bool isUnary = ChunkByImplIsUnary!(pred, Range);

        static if (isUnary)
            alias eq = binaryFun!((a, b) => unaryFun!pred(a) == unaryFun!pred(b));
        else
            alias eq = binaryFun!pred;

        // Outer range
        static struct Impl
        {
            size_t groupNum;
            Range  current;
            Range  next;
        }

        // Inner range
        static struct Group
        {
            private size_t groupNum;
            private Range  start;
            private Range  current;

            private RefCounted!Impl mothership;

            this(RefCounted!Impl origin)
            {
                groupNum = origin.groupNum;

                start = origin.current.save;
                current = origin.current.save;
                assert(!start.empty);

                mothership = origin;

                // Note: this requires reflexivity.
                assert(eq(start.front, current.front),
                       "predicate is not reflexive");
            }

            @property bool empty() { return groupNum == size_t.max; }
            @property auto ref front() { return current.front; }

            void popFront()
            {
                current.popFront();

                // Note: this requires transitivity.
                if (current.empty || !eq(start.front, current.front))
                {
                    if (groupNum == mothership.groupNum)
                    {
                        // If parent range hasn't moved on yet, help it along by
                        // saving location of start of next Group.
                        mothership.next = current.save;
                    }

                    groupNum = size_t.max;
                }
            }

            @property auto save()
            {
                auto copy = this;
                copy.current = current.save;
                return copy;
            }
        }
        static assert(isForwardRange!Group);

        private RefCounted!Impl impl;

        this(Range r)
        {
            impl = RefCounted!Impl(0, r, r.save);
        }

        @property bool empty() { return impl.current.empty; }

        @property auto front()
        {
            static if (isUnary)
            {
                import std.typecons : tuple;
                return tuple(unaryFun!pred(impl.current.front), Group(impl));
            }
            else
            {
                return Group(impl);
            }
        }

        void popFront()
        {
            // Scan for next group. If we're lucky, one of our Groups would have
            // already set .next to the start of the next group, in which case the
            // loop is skipped.
            while (!impl.next.empty && eq(impl.current.front, impl.next.front))
            {
                impl.next.popFront();
            }

            impl.current = impl.next.save;

            // Indicate to any remaining Groups that we have moved on.
            impl.groupNum++;
        }

        @property auto save()
        {
            // Note: the new copy of the range will be detached from any existing
            // satellite Groups, and will not benefit from the .next acceleration.
            return typeof(this)(impl.current.save);
        }

        static assert(isForwardRange!(typeof(this)));
    }

    auto chunkBy(alias pred, Range)(Range r)
        if (isInputRange!Range)
    {
        return ChunkByImpl!(pred, Range)(r);
    }
}
/**

    Collection of symbols needed for compatibility with earlier
    D compiler frontend versions
*/

module mood.util.compat;

static if (__VERSION__ < 2067L):

import std.functional;
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

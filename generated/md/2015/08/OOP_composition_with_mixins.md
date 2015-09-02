<!--
Title: OOP composition with mixins
Date: 20150824T155012.494947
Tags: code
-->
I gave a very small talk for a recent [Berlin D
meetup](http://www.meetup.com/Berlin-D-Programmers) about approaches to make
OOP style designs more robust with tools available in D. Normally I am quite
quite skeptical about OOP in general and prefer to write code in a mix of
functional and generic style but often there is that big chunk of old code that
works just fine and you are not going to rewrite it just to switch the
paradigm. Tweaking slightly for improved maintainability totally makes sense
though.

## Theory

### Common Approach

Looking through existing source of what is called "OOP-style code" you most
commonly find design revolving about two basic principles:

1. Defining reused code in base class methods
2. Tweaking behavior by overriding some of those methods

This is dominating approach in Java and very common in C++ projects. It was
also relatively common design style in D during old days of D1, affecting also
[Tango library](http://www.dsource.org/projects/tango) we still use in our
(Sociomantic) projects.

Funny thing about this approach is that it has been discouraged as bad OOP
style for a very long time.

### Oops

> Favor 'object composition' over 'class inheritance' (Gang of Four, 1994)

This a quote from a famous "Design Patterns" book, still one of most respected
works about practical application of OOP principles. And of all patterns and
advices this has probably been the least recognized one in real projects.
Sadly.

There is even a dedicated [wiki page for
that](https://en.wikipedia.org/wiki/Composition_over_inheritance).

What makes inheritance-driven code reuse bad?

1. It results in bunch of base classes that don't represent any meaningful
   abstraction, violating OOP concept of "object". Usually when you
   see a class named "SomethingBase" in your code, this is a clear sign
   something has gone wrong.
2. It doesn't naturally scale unless your language allows multiple class
   inheritance (which will cause you suffering for other reasons). Adding
   new reusable utilities to derived classes becomes impossible without
   refactoring whole involved class hierarchy.
3. Much less flexible than it may seem from simple cases. You are
   inherently limited to only overriding methods that are not final and
   which have been defined as distinct separate methods from the very
   beginning. If the base class author was not good enough at predicting
   all use cases (and nobody is perfect), you are pretty much doomed
   into a lot of copy-paste.

Sadly, those issues tend to only come up when applications reach maintenance
cycle when reconsidering is not really an option anymore. Which starts a usual
painful process of moving classes around and trying to reason with incredibly
complicated hierarchies people so commonly associate with OOP.

### Composition

Composition is an alternative approach for code reuse which implies that you
define necessary utilities as small independent objects (as small as possible)
and embed them within target class as building blocks, usually as private
fields. Thus the name -- the programmer is supposed to compose such blocks into
any set of features the target class needs.

I have a feeling that one of reasons the old advice of GoF was ignored so often
in mainstream languages is that those simply don't provide any useful tools to
minimize the involved boilerplate. Fortunately, D has something to offer here:

- [alias this](http://dlang.org/class.html#alias-this)
- [opDispatch](http://dlang.org/operatoroverloading.html#dispatch)
- [template mixins](http://dlang.org/template-mixin.html) (topic of this article)

I will focus on template mixins here because it is a tool also available in D1
and thus more applicable to my daily job :)

## Practice

### Template Mixins : Basics

Essentially template mixins are a more hygienic and controlled way to copy
declarations:

```D
mixin template InjectMe(T)
{
    T var;
}

class C
{
    mixin InjectMe!int;
}

static assert (is(typeof(C.var) == int));
```

(declaring the template as a mixin template is not necessary but it's useful to
convey the usage intentions)

To resolve naming conflicts, one can use named mixins:

```D
class C
{
    mixin InjectMe!int name;
}

static assert (is(typeof(C.name.var) == int));
static assert (is(typeof(C.var) == int));
```

Usage of named mixins is highly recommended because, as you can see from this
example, in the absence of name conflict, "short" version also works - thus you
don't lose anything but it makes the code more forward-compatible if new fields
get added later.

### Template Mixins : Alias

However what makes template mixins truly shine as a composition tool is the
[template alias
parameter](http://dlang.org/template.html#TemplateAliasParameter).

```D
import std.range.primitives : isInputRange;
import std.traits : isArray;

// makes host aggregate an input range which
// consumes target array when iterated but does
// not allow to modify its elements
mixin template ConsumeAsRORange(alias array)
{
    static assert (isArray!(typeof(array)));

    bool empty() { return array.length == 0; }
    auto front() { return cast(const) array[0]; }
    void popFront() { array = array[1 .. $]; }
}

class C
{
    private int[] secret_array;
    mixin ConsumeAsRORange!secret_array;
}

static assert (isInputRange!C);
```

`alias` parameter is how D does "pass by name" semantics. All template
arguments must be compile-time entities so you can't pass `secret_array` itself
like that as it is a field of runtime object. Yet you can pass its symbol name
and `alias` will make use the of context pointer to resolve a field for a
proper object, acting as certain form of a delegate.

Of course you could just drop any parameters completely and use
`this.secret_array` directly - as whole mixin body gets pasted into the
aggregate, it would resolve properly.  However, this a terrible coding style I
heavily discourage from, one that will make your code completely
unmaintainable.

The beauty of `alias` parameters is that they allow you to define generic
reusable building blocks that hold no silent assumptions about their mixin
context - all dependencies can be expressed explicitly and have full
compile-time verification with nice error messages from `static assert`.

The main limitation of this feature is that right now it is limited to only one
context pointer and is sometimes not smart enough to recognize transitivity:

```D
class C
{
    struct S { int[] secret_array; }
    S s;
    // won't compile
    // need context pointer for both C and S and compiler
    // isn't smart enough yet to see latter can be retrieve
    // from the former
    mixin ConsumeAsRORange!(s.secret_array);
}
```

### Design Principles

With the above-mentioned features in mind I suggest following design principles
when doing composition-driven OOP with D programming language: 

- provide reusable functionality as a small building blocks
- define all expectations for the mixin context via template parameters
- `static assert` a lot (including `typeof(this)` verification)
- compose actual classes from those building blocks as necessary
- reserve inheritance to useful abstractions

### Primary Candidate : Exceptions

Exceptions have their own hierarchy which, once defined, is almost impossible
to change without major code breakage (on the catching side).

That makes reusing code by inheritance simply impossible. For example, we often
need exceptions that build messages in a persistent mutable buffer (to avoid GC
allocations each time) and this is quite a bunch of fields and methods to copy:

```D
class MyException : IOException
{
    mixin ReusableExceptionImpl!();
}
```

Yet mixins make it trivial without compromising the existing exception
hierarchy.

### "override"

With inheritance partial tweaking of provided utilities is achieved by
overriding methods. With mixin based approach there are two main options:

#### shadowing

```D
mixin template Inject()
{   
    void foo() { writeln("foo injected"); }
    void bar() { writeln("bar injected"); }
}

struct S
{
    mixin Inject!();
    void bar() { writeln("bar overriden"); }
}

void main()
{
    S s; s.foo(); s.bar();
}
```

Using a named mixin allows to still refer to original version, same
as with using `super` when overriding.

#### reimplementing

If the provided building blocks are small enough, the simplest approach is to
not mixin at all and provide your own implementation of method with same
signature:

```D
struct S1
{
    mixin FooImpl!(); // provides `this.foo`
    mixin BarImpl!(foo);
}

struct S2
{
    void my_foo() {}
    mixin BarImpl!(my_foo);
}
```

This is better suited for cases when the mixed in functionality is mostly
unrelated.

## Abrupt Ending 

And this where is suddenly ends because I didn't have enough time to prepare
more content for the talk :) Hope it gives at least some basic insight into the
topic.

I will look into writing another post which could feature examples of applying
promoted techniques to our production code but that will require getting few
publishing permissions here and there so no hard promises.

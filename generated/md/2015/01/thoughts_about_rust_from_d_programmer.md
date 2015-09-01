<!--
Title: Thoughts about Rust from D programmer 
Date: 20150112T010101.000000
Tags: code
-->
I have been following development of [Rust](http://rust-lang.org) for a while
now - both occasional blog posts that get popular on reddit and some of mail
list threads with more theoretical discussions. My job is all about the [D
programming language](http://dlang.org) though so it was hard to find time to
try it in more detail.

With recent release of 1.0.0 alpha version of the compiler I decided to spend
time to get a bit more familiar with it. First thing to do was to start reading
the [official guide](http://doc.rust-lang.org/1.0.0-alpha/book) and making
notes on stuff. And those notes are exactly what I want to share here.

Just to be clear : I won't be trying to compare available tools, documentation,
compiler quality and anything else related to ecosystem. It is all about pure
language and what comes from it. There will be bunch of unstructured notes on
that topic with a sort of overall impression summary in the end.

Also please note that this list is very incomplete and focuses only on things I
could write about in reasonably short form. Maybe more comparisons will follow
if I continue experimenting with it.

## Good

### Immutability by default

In Rust variables / arguments are immutable unless explicitly marked as
mutable. In D it is other way around and so far it seems to me as one of most
fundamental design mistakes. Practice has shown that people won't bother with
adding extra annotation or attributes unless it is actually needed to make code
compile/work. Same applies to concepts like purity (which sadly does not exist
in Rust).

I have come to the opinion that whenever you have any type qualifiers,
especially transitive ones, the most restrictive one should always be the
default. It encourages more disciplined code in most natural fashion - code
won't compile unless you ask for necessary permissions explicitly.

What makes situation worse is that we can't realistically change that decision
in D as it affects pretty much every line of code out there. Which leads to
complicated workarounds like whole-program attribute inference.

It is good to see Rust has decided to be strict here.

### No implicit conversions

D code:
```D
int x = int.max;
// Error: cannot implicitly convert expression (x) of type int to short
short y1 = x;
// OK
uint y2 = x;
```

Rust code:
```Rust
use std::i32;
let x = i32::MAX;
// error: mismatched types: expected `u32`, found `i32` (expected u32, found i32)
let y : u32 = x;
// OK
let y = x as u32;
```

As you may notice D prevents only implicit casts that would result in data loss
like from 32-bit signed integer to 16-bit signed integer. Reinterpreting same
integer as 32-bit unsigned is considered OK and done implicitly.

It has caused bugs in my code more than once and I really appreciate necessity
for an explicit cast in Rust code.

### Pattern matching

Pattern matching is slowly becoming more and more important part of my casual
programming style and having built-in support which is actively used by
standard library is big advantage in my opinion. And I mean specifically
exhaustive match:

```Rust
match x {
    Value(n) => println!("x is {:d}", n),
    Missing  => println!("x is missing!"),
}
```

Even something as basic as [exhaustive
switch](http://dlang.org/statement.html#final-switch-statement) in D has been
catching small annoying maintenance bugs regularly in my experience. Ensuring
that whenever you handle some data all cases get handled and fine-tuning
those cases is very sweet.

It is quite telling that we already do pattern patching via delegates in D too:

```D
receive(
    (int i)            { writeln("Received the number ", i); },
    (double d, char c) { writeln("Received two items"); }
);
```

This is an example code for D standard library
[concurrency module](http://dlang.org/phobos/std_concurrency.html) and it is
exactly kind of task where pattern matching shines to perfection. It works but
Rust version is both more light-weight and robust at the same time.

Appreciated.

### Minimal runtime

[Rust FAQ](http://doc.rust-lang.org/complement-design-faq.html#the-language-does-not-require-a-runtime)
mentions this as an explicit design goal that was there since the very start. I
personally think this was one of most important design decisions taken as it
allows people interested in different domains to build necessary extensions on
top of standard compiler and tools.

At the same time there has always been a disappointment about using D in
barebone environment. It is
[entirely possible](http://dconf.org/2014/talks/franklin.html) and may enable
some cool things but overall experience of getting there is rather
terrible - need to avoid some of language features, can't use most of
standard library, need to tweak/trick the compiler to stop expecting the
runtime as a given.

I am still pretty sure we can provide good experience for embedded developers
with no revolutionary changes but getting there is for sure harder then for the
Rust guys because of that initial runtime coupling.

### Imports + symbol visibility

This is something that has started to annoy me only recently after some years
of using D in production so seeing it already "fixed" in Rust was a pleasant
surprise.

Consider this trivial D module:

```D
module mymod;

void foo() {}
```

Most natural way to use it will look like this:

```D
module other;
import mymod;

void main()
{
        foo();
}
```

It looks perfectly OK in a simple application. However eventually you will
import two modules which both have symbol named *foo* and it will
clash requiring explicit qualification:

```D
module other;
import mymod1;
import mymod2;

void main()
{
    mymod1.foo();
}
```

This is mostly annoying for a common names present in standard library module -
`write`, `text` and so on. What is really bad here is that you can't partially
qualify such symbol:

```D
module other;
import my.long.mod1;
import my.long.mod2;

void main()
{
   // nope
   mod1.foo();
   // full qualification only
   my.long.mod1.foo();
}
```

This can become very annoying in big projects with deeply nested module/package
hierarchy and encourages people to use hacks like "namespace structs" (structs
with only static members) to emulate namespace hygiene. Which is exactly what D
module system was trying to fix!

With all that in mind it must be clear why this Rust snippet has made me so happy:

```Rust
extern crate phrases;

use phrases::english::greetings;
use phrases::english::farewells;

fn main() {
    println!("Hello in English: {}", greetings::hello());
    println!("Goodbye in English: {}", farewells::goodbye());
}
```

What is awesome here is that `use` puts imported symbol itself into local
symbol table and not all its members. That encourages everyone to use at least
one level of qualification for all symbols and this indeed advertised as a good
style in Rust guide. With this approach chance of clashes even for most common
names is almost non-existent and qualified names are kept reasonably small.

One thing that worries me here though is that packages (crates) are kept so
distinct in importing code from modules. This seems to reduce flexibility of
refactoring in libraries without breaking user code (D has a feature that
allows to turn module into package non-intrusively).

It is complex topic with many far reaching consequences though so I'd better
not be quick in criticizing this decision.

*Update:* it has been noted that one can use this D idiom to get same semantics:

```D
module other;
import mod1 = my.long.mod1;
import my.long.mod2;

void main()
{
    // ok
    mod1.foo();
    // ok too, means my.long.mod2.foo
    foo();
}
```

which is correct and I am often using this idiom. But it can't be accepted as a
real solution exactly because it is an idiom and not enforced in any way.

It may be OK if all code is under your control and it is only matter of code
review / lint tool. Once 3d party libraries come into question it quickly
becomes a mess anyway because some will have custom namespace structs and some
will rely on such aliased import. So you can't have simple "always use
shortened alias import" rule in your project. It becomes worse in Phobos
because plain stupid import is perfectly legal and we (Phobos developers) are
obliged to care about those who don't use specific idioms too. Which results in
extremely annoying and arbitrary "no name clashes within Phobos" policies and
heated name debates for modules like `std.log`.

Rust approach here is superior because they chose behavior that is less likely
to clash as default one even at cost of convenience for trivial scripts. Which
makes sense because they don't care about trivial scripts and having a niche
helps.

Implementing similar importing mechanism in D can be done quite easily, but
making it default and adjusting projects layouts is not realistic though. And
this is what really matters.

## Uncertain

### Tuples

Rust tuples seem to generally match
[std.typecons.Tuple](http://dlang.org/phobos/std_typecons.html#.tuple) in D but
with better built-in language support that allows thing like pattern-based
unstructuring. It is nice and makes them simple to understand.

But I was not able to find anything about type tuples in official guide and
judging by [this issue](https://github.com/rust-lang/rfcs/issues/376) there are
no variadic generic either right now. This makes me fear that relevant
functionality either won't be introduced (breaking my heart) or be defined even
in more awkward and alien way than in D.

Value tuples and type tuples often inter-operate in generic code and having
well-define relation between those is very important.

### Ownership / lifetime system

It may surprise you to see here the feature that is widely considered most
distinctive and cool thing about Rust. Yet I am uncertain.
Don't get me wrong - it is awesome and enables huge amount of compiler-verified
code patterns both for memory safety and concurrency. I love that.
We have been trying to introduce something similar (but much less powerful) for
some time in D too, with no real success so far - and that makes me respect
even more any actually implemented system that works.

It is complicated though. Complicated in a way that seems impossible to opt-out.
You can't just hire a new programmer for Rust project and make him start doing
more straightforward things before unleashing the madness of ownership system
- it is there straight from the very beginning and you need to respect it.

How complicated it really is? Well, as I have already mentioned, I have been
participating in discussions about designing similar language feature in D and
generally curious about this topic. And yet any time I am trying to write any
non-trivial Rust code I find myself checking the reference manual again and
again to get things right. It is worrying.

Once you become comfortable with it though, achieved awesomeness is just beyond
measure. This can be an absolute deal-breaker for writing systems that need to
be both fast and strictly correct and my C embedded background is very cheerful
about it. Question is: how niche you can really afford to be?

### Implicit return

Short rant about this:

```Rust
fn foo() -> int {
        42
}
```

It is very common among functional languages to evaluate returns implicitly
like this and not common at all among C programmers :) I doubt it will cause
any bugs but I really miss being able to quickly look at the function code and
see all return points immediately. At least right now.

## Bad

### `#[cfg(not(test))]`

*THIS IS HORRIBLE*

Well it may look OK to C programmers who hardly use anything but `#ifdef`
It may even work for typical cases without too much pain. But I am used to
power and elegance of D compile-time versioning constructs:

```D
version (unittest)
{
    // anything
}
else
{
    // anything!
}

static if (ANYTHING_THAT_EVAULATES_TO_BOOLEAN)
{
    // anything!
}
```

It is simply not comparable. Also I wonder how soon this attribute combination
syntax becomes powerful enough to be Turing-complete and we start seeing ray
tracers written in Rust `#[cfg]` blocks. Or probably it already is? :)

### Purity

I am surprised Rust has so many things from functional languages and
immutability by default but it does not seem to have any notion of verified
purity. I know that defining purity precisely can be challenging in
multi-paradigm language but there is a very useful most basic notion "function
that does not access any global state other than via arguments". It is not
enough to enable optimizations like memoization but it is enough to greatly
simplify reading big code bases - and fits the Rust design principles as far as
I can see.

Those interested in D two notions of purity ("strongly pure" and "weakly pure")
are welcome to read [this small section of official
docs](http://dlang.org/function.html#pure-functions) this small section of
official docs. It hasn't been killer feature for D so far but it is nice
and helpful and Rust to be a naturally better match for that kind of
restrictive things.

### Syntax

This makes me frustrated every time I see it:

```Rust
let i = from_str::<uint>("42");
```

Seriously? Is it some sort of Java or a modern language with decent generics
and strong type system? Why the function has to be named `from_str`, can't it
deduce the type of the argument because it is, well, string?

Why it is even name `from_something` as opposed to `to_something`? How often
does former matter to the reader compared to the latter?

Is `::<>` syntax chosen intentionally to scare people away from generics and
never return back unless no other choice is available? Is it really hard to
define a grammar that is both easy to parse *and* to read?

It must be obvious that various weird syntax moves were most annoying things
for me when trying to read the guide :) I am not the scripting language fan who
wants to get rid of every single symbol and do magic. But I want simple
things to look as simple as possible, as long as it doesn't harm other
parts of the language. So far Rust seems to fail very hard here compared to D.

## Overall

In general I like Rust a lot. Quite possible I like it even more than D. At the
same time if I ask myself "why would I ever chose Rust for business purpose?"
right now answer does not look very encouraging.

D suffers from being overly generic and trying to appeal everyone inevitably
frustrating many because of interest conflict. Rust seems to have reverse
issue - it is so focused on one specific (hard) niche that casual usage may become
impractical. And it is not like there are thousands of good unemployed
developers running around all packed with a math degree and solid grasp of
language design concepts.

However if Rust developers ever start compromising on special cases to make
syntax less "noisy" and simple things simple it may suddenly become a very
tempting language to use in performance-critical software, even without
unlimited hiring budget. It is pretty damn close.

<!--
Title: Testing D projects with Gitlab CI and Docker
Date: 20170225T010101.000000
Tags: code
-->

For a long time CI testing has not been something that one would pursue in a hobby
project. Doing something like setting own Jenkins instance was a considerable
effort and don't forget about server expenses to host it somewhere. Not a fun
thing to do in your spare time.

Sadly, the mentality persists even today in many ways. But situation has become
much different - now there are plenty of tools and services available that make
adding CI so easy that there is literally no excuse to not do it even for most
trivial hobby projects.

## Going bleeding edge

The most common service for hosting open-source projects these days is of course
GitHub. And if CI system is present, it will most likely be Travis CI. Not a bad
choice overall and definitely better than nothing but this approach felt lacking
to me because of various minor issues:

- There isn't much control over test environment in Travis - just few base
  systems and you have to install/setup everything as part of CI process
- GitHub integration of CI services is very simplistic - those can mark specific
  commits as red or green and that is pretty much it
- No way to provide own hardware as test slave if system limits become an issue

And when I started to play with [GitLab](https://gitlab.com) and CI system it provides
out of the box I have immediately fallen in love with it. It starts working
automatically as soon as `.gitlab-ci.yml` file is pushed to the branch and uses
[Docker](https://docker.com) as a base for test runners. And test results are integrated
into GitLab project UI. Pretty nice.

Let's have a closer look!

## Basic example

I am going to use [one of my simple
projects](https://gitlab.com/dicebot/libmpcd) as an example for the rest of the
article. It is a very simple project - just set of C bindings and higher level D
wrappers for [libmpdclient](https://www.musicpd.org/libs/libmpdclient), but one
can still verify a lot of things with a CI:

- check that it actually compiles
- check that usage examples compile
- run some API tests
- ensure coding style
- generate documentation

This is the most basic `.gitlab-ci.yml` file to ensure projects compiles and run
its unit tests:

```
image: dicebot/archlinux-dlang

unittest:
    script:
        - dub test
```

Here `unittest` is just an arbitrary name to one of CI scripts (the only one
present in this example). As soon as it gets pushed as part of a merge request,
the CI pipeline will start, no extra effort required! It will execute `dub test`
command and if it returns exit code 0, the pipeline succeeds.

`image` defines base docker image to use for testing and that is the beauty of
GitLab approach that makes setting up even very complex CI environment so
easy. The name can be any valid image name from the [docker
registry](https://hub.docker.com), including one you have created and pushed yourself.
That allows to prepare arbitrary system on your development machine, install any
required packages and tools, make sure it works for tested project and simply
commit/push it after, knowing that CI will run with the exactly same system.

## Compiling examples & parallel scripts

Very annoying issue with many open-source projects is that old usage examples
stop working when the code evolves and no one notices that. Let's ensure this
won't ever happen and run CI tests in parallel while we are at it:

```
image: dicebot/archlinux-dlang

stages:
    - test

unittest:
    stage: test
    script:
        - dub test

examples:
    stage: test
    script:
        - for example in examples/*; do dub build --single $example; done
```

Important thing here is `stages` section - each item in it defines new test
block so that all blocks will be run in same order as listed. Here only one test
block is defined (named `test`) and both scripts belong to it, which means they
will be run in parallel.

That was easy. What about case when you do actually want sequential execution?

## Generating and publishing docs

Similar to GitHub, GitLab allows to serve static web content with a Pages
services. But it also allows to update that content as part of the very same CI
pipeline, which is a perfect tool for keeping up to date documentation
published!

```
image: dicebot/archlinux-dlang

stages:
    - test
    - docs

pages:
    stage: docs
    only:
        - master
    script:
        - hmod source -o public
    artifacts:
        paths:
            - public
```

In this example I am using two sections - first `test` scripts are run and if
all those succeed, `docs` script is executed. It gets rendered nicely in the UI
too, by the way, check it out: https://gitlab.com/dicebot/libmpcd/pipelines/6546360

Compared to test scripts show before, `pages` section is a bit more complicated
here. It uses `only` setting to indicate that docs must be generated for master
branch only (don't want to publish every merge request content). And `artifacts`
setting is the one that tells that web contents needs to be published - and
which one exactly to publish.

Script to generate D project documentation uses
[harbored-mod](https://github.com/kiith-sa/harbored-mod) which is a nice tool if
one is not satisfied with DDOC alone and wants to add some Markdown in the box.

Resulting content is published to https://dicebot.gitlab.io/libmpcd - sorry, I
have never got to work on nice styling.

## More dependencies

To run API tests I need MPD server running and original C library to link
against. My test image is based on [Arch Linux](https://archlinux.org) thus new packages
can be added with `pacman`:

```
before_script:
    - pacman -S --noconfirm libmpdclient

unittest:
    stage: test
    script:
        - dub test

api:
    stage: test
    script:
        - pacman -S --noconfirm mpd
        - dub run :api-tests
```

Commands in `before_script` section will be run before each of test scripts,
thus it is best suitable for setting up common environment that will be needed
for all of tests. In this example I only need `mpd` instance running for
API tests, so it is done as part of relevant script only.

Important thing to keep in mind here is that docker image caching is rather
imperfect in such system. If you have a lot of extra dependencies to install,
consider creating new base image that includes them all and switching to it
instead - this can reduce total time taken by the pipeline considerably.

## Last touches

The example project also does hard style checks as part of the testing stage:

```
coding_style:
    stage: test
    script:
        - dfmt source/**/*.d
        - git diff --exit-code
```

I know that such hard requirement can feel annoying to some/many developers but
in the end not having to pay any attention to coding style during merge request
reviews is a nice productivity gain.

And this is how final CI script looks like:

```
image: dicebot/archlinux-dlang

before_script:
    - git submodule update --init
    - pacman -S --noconfirm libmpdclient

stages:
    - test
    - docs

unittest:
    stage: test
    script:
        - dub test
api:
    stage: test
    script:
        - pacman -S --noconfirm mpd
        - dub run :api-tests
examples:
    stage: test
    script:
        - for example in examples/*; do dub build --single $example; done
coding_style:
    stage: test
    script:
        - dfmt source/**/*.d
        - git diff --exit-code
pages:
    stage: docs
    only:
        - master
    script:
        - hmod source -o public
    artifacts:
        paths:
            - public
```

Of course there are lot more topics to potentially talk about - GitLab CI comes
with plenty of [features](https://docs.gitlab.com/ce/ci/) and there is always
something that can be improved. But my goal was quite different - to show how
simple is getting help from CI is these days and encourage to use more of it
every day.

Happy coding!

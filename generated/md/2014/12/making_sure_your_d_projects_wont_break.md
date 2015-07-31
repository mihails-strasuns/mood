<!--
Title: Making sure your D projects won't break
Date: 20141214T010101.000000
Tags: code
-->

This is one very common reason for many polite insults in D community - new
compiler (or any other upstream project) gets released, your lovely application
breaks and stops compiling. You blame surprisie regressions, users blame you
not updating the application / library, Walter blames everyone not paying
attention to beta mail list. Nothing works, everyone is unhappy, yay!

There are many things that can possibly be done about better release policy,
stability guarantees and release versioning. Probably I will write about it
some other day. Problem with all that stuff is that someone out there needs to
do something about it, not so much for you personally. Unless you want to join
DMD development team of course.

One great thing available for everyone though is better regression control. It
is easy to miss beta announcements and hard to find time to test all your
applications exactly when beta period is open. However you don't need to wait
for beta - file issues as soon as they break your applications and there is a
very good chance new release simply won't happen until it is fixed.

And I have just finished configuring something that takes care of it for me
based on Jenkins - anyone impatient can have a look at
https://jenkins.dicebot.lv to get an idea what this is going to be about.

## Toolstack

1. Some server capable of building D projects. I have a dedicated home server for that, VPS is OK too but you will likely to need at least 2GB of RAM to do anything useful.
2. Jenkins package. I use Arch Linux and it was available in community repository - with default configuration being perfectly suitable for my needs.
3. Packages needed for building DMD / dub - curl library was needed for the latter in my case, not counting default make / gcc

## Idea

At this point you might be wondering if I am completely stupid and have never
heard of Travis which allows to add continuous integration for your projects
for free with additional test platforms easily added and even recently
announced D support 

I am not and I sincerely advise you to actually start using it for internal
regression control as it is rather hard to get anything more robust from
personally configured CI system without much effort, especially if multiple
platforms need to be tested.

One important thing it doesn't do though is supporting good build job
pipeline. Consider two main upstream projects most commonly used in D
community to build stuff - DMD and dub. To ensure nothing breaks with new
release I want to regularly test my projects with:

1. master version of DMD + last stable release of dub
2. last stable release of DMD + master version of dub
3. any additional upstream projects built by both (1) and (2)

Then, if at any point build of my application / library fails I can simply look
at combination of upstream project versions that has caused this and
immediately report bug upstream - marking it as REGRESSION/CRITICAL, no less :)

## Implementation

There are two crucial Jenkins plugins that make it easily possible:

* https://wiki.jenkins-ci.org/display/JENKINS/Copy+Artifact+Plugin - allows copying artifacts (files) from upstream jobs to current workspace
* https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugin - makes possible to start downstream jobs with optional parameters to use (upstream job name in my case)

This is example of a shell script for dlang-git-master job I have configured to build daily:

```
git clone https://github.com/D-Programming-Language/dmd.git

cd ./dmd
git show --abbrev-commit --shortstat
make -f posix.mak MODEL=64 RELEASE=1
cd ..

git clone https://github.com/D-Programming-Language/druntime.git

cd ./druntime
git show --abbrev-commit --shortstat
make -f posix.mak MODEL=64 RELEASE=1
cd ..

git clone https://github.com/D-Programming-Language/phobos.git

git show --abbrev-commit --shortstat
cd ./phobos
make -f posix.mak MODEL=64 RELEASE=1
cd ..

# prepare artifacts
mkdir -p artifacts/imports
cp ./dmd/src/dmd ./artifacts/dmd
cp -r ./phobos/{*.d,etc,std} ./artifacts/imports/
cp -r ./druntime/import/* ./artifacts/imports/
cp ./phobos/generated/linux/release/64/libphobos2.a ./artifacts/
echo -e "[Environment]\nDFLAGS=-I%WORKSPACE%/artifacts/imports -L-L%WORKSPACE%/artifacts" > ./artifacts/dmd.conf
tar -czf artifacts.tar.gz artifacts
```

As DMD does not currently provide nightly builds, there is no other way than to
build those manually. Luckily it is simple and this job finishes in few minutes
on my server. If at some points we get nightlies you may consider using those
instead to allow cheaper VPS plan - I personally prefer to build everything
from source though.

I have adopted convention to use `./artifacts` folder for all combined upstream
files to ensure any required binary / library can be found under the same path.
This is how artifacts get amended in downstream dub-release job:

```
tar -xzf artifacts.tar.gz
export DC=$WORKSPACE/artifacts/dmd

cd dub
./build.sh
# now bootstrap
./bin/dub build
./bin/dub test

cp ./bin/dub $WORKSPACE/artifacts/
cd $WORKSPACE
tar -czf artifacts.tar.gz ./artifacts
```

You may notice that in this case I don't manually clone the repo in shell
script - built-in Jenkins cloning tools available in job configuration are used
instead. Using those should be generally preferred as it both results in more
useful information in the interface and reduces net load by using local repo
cache for any remote repo instead of doing full remote clone each time. The
reason why it wasn't used in first (dmd) job is because it only supports single
git repo per job currently.

And this is example of final downstream project job:
https://jenkins.dicebot.lv/job/libsdl-d

Instead of having specific project defined in "copy artifacts from" field, I
use a parameter `$upstream_job` there. And with the help of
[parameterized trigger plugin](https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugin)
I start this job from both dub-release and dub-git-master while setting this
parameter accordingly.

As a result I get a build pipeline consisting from arbitrary amount of projects
with upstream-downstream relation which test different upstream combination
environments - and make me immediately know if that effects any of my projects.
This works best when combined with "casual" continuous integration provided via
Travis to catch any regressions you have introduced yourself (and thus ensure
your application / library is in good state itself)

## Welcome!

It is quite likely that only few of you will want to spend that much time to
simply be able to report regressions in time. I'd still want to see much more
healthy library ecosystem out there thus simple proposal - poke me via
[e-mail](mailto:public@dicebot.lv) and I will gladly add any of you projects
to the system I have already configured. There is a one requirement though :
you must be willing to actually investigate found regressions and report them
to bugzilla or workaround in your project. If that sounds OK to you, just let
me know.

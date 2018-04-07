Subject:      Branch Conventions

Abstract:     Defining standard grouping nouns, abbreviations, and best
              practices for naming new git branches.  Also defines development
              strategy branch model.

Author:       Daniel K. Ives
Email:        daniel.ives@live.com

Recognition:  phord, on stackoverflow.com
              Vincent Driessen, nvie.com, a-successful-git-branching-model

-------------------------------------------------------------------------------
NAME SYNTAX
-------------------------------------------------------------------------------
<pri-group>/[sub-group>/][issue-num_]<name-token>


<pri-group>     Described in the noun sections below...

<sub-group>     Described in the noun sections below...

[issue-num]     Associated id number if an issue tracker is used.

                !!WARNING!!

                Do not use bare numbers or hex digits at the start of an issue
                number as git may confuse it as part of a SHA-1 ID instead of a
                branch name!  To avoid this problem, always prefix the issue
                number with a standard non-hex alpha character.

<name-token>    The descriptive portion of the branch name that identifies the
                abstract purpose of the branch.  Best practice is to keep the
                names short and use dashes "-" between words.

-------------------------------------------------------------------------------
GROUPING BRANCHES WITH NOUN DESCRIPTORS
-------------------------------------------------------------------------------
Grouping nouns allow you to quickly locate branches using Git's pattern
matching:

     $ git branch --list "feat/test/*"
     feat/test/foo
     feat/test/bar

     $ git branch --list "*/foo"
     feat/test/foo
     bug/vfy/foo


                USE SLASHES TO DELIMIT GROUP NOUNS

!!WARNING!!

Slashes can cause problems! Because branches are implemented as paths, you
cannot have a branch named "foo" and another branch named "foo/bar". This can
be confusing for new users.

While you may use most any delimiter in branch names, using slashes allows you
to do some branch renaming when pushing or fetching to/from a remote
repository:

     $ git push origin 'refs/heads/feature/*:refs/heads/phord/feat/*'
     $ git push origin 'refs/heads/bug/*:refs/heads/review/bugfix/*'

-------------------------------------------------------------------------------
PRIMARY GROUPING NOUNS
-------------------------------------------------------------------------------
Primary grouping nouns are used to identify the purpose of the development
branch.

bug     - Bug fix: a less urgent bug integrated in the next release.
dev     - Development: a permanent branch that runs parallel to master.
exp     - Experimental: throw away branch created for experimentation.
feat    - Feature Addition or Expantion.
hot     - Hotfix: a severe bug that must be fixed immediately.
rel     - Release

-------------------------------------------------------------------------------
SUB-GROUPING NOUNS
-------------------------------------------------------------------------------
Sub-grouping nouns are used to indentify the development cycle that the branch
is currently in.

new     - A fresh development branch.
wip     - Work in Progres: code with expected long development timelines.
test    - Test: built it, but does it work.
vfy     - Verify: undergoing suitability, logic, and convention validation.

-------------------------------------------------------------------------------
DECENTRALIZED BUT CENTRALIZED
-------------------------------------------------------------------------------
The repository setup that we use and that works well with this branching model,
is that with a central "truth" repository.  Note that this repository is only
considered to be the central one (since Git is a DVCS, there is no such thing as
a central repository at a technical level).  We will refer to this repository as
origin, since this name is familiar to all Git users.

          alice                                                david
    -------------------  <--------------------------->  -------------------
    |             +-* |         subteam fetches         |             +-* |
    |       _____/  | |   _                          _  |       _____/  | |
    |      /        | |  <_\                        /_> |      /        | |
    |     *         | |    \\                      //   |     *         | |
    |     |         | |     \\                    //    |     |         | |
    |   +-*         | |      \\                  //     |   +-*         | |
    |  /  |         | |       \\                //      |  /  |         | |
    | *   *         | |        \\              //       | *   *         | |
    | |   | \       | |         ||            ||        | |   | \       | |
    | *   |  \____  | |         \/            \/        | *   |  \____  | |
    |  \  |       \ | |             origin              |  \  |       \ | |
    |   \ |         * |        -----------------        |   \ *         * |
    |     *         | |        |              | |       |     *         | |
    -------------------        |              * |       -------------------
          /\                   |        _____/| |               /\
          ||                   |       /      | |               ||
          || subteam           |      *       | |               || subteam
          || fetches           |      |       | |               || fetches
          ||                   |      *       | |               ||
          \/                   |     /|\      | |               \/
                               |    / | \     | |
            bob                |   *  *  \    | |              clair
    -------------------        |   |  |   *_  | |       -------------------
    |             +-* |        |   *  |      \| |       |             +-* |
    |       _____/    |        |    \ *       * |       |       _____/  | |
    |      /          |        |     \|         |       |      /        | |
    |     *           |        |      *         |       |     *         | |
    |     |           |        ------------------       |     |         | |
    |   +-*           |                                 |   +-*         | |
    |  /  |           |        /\            /\         |  /  |         | |
    | *   *           |        ||            ||         | *   *         | |
    | |   |           |       //              \\        | |   | \       | |
    | *   |           |      //                \\       | *   |  \____  | |
    |  \  |           |     //                  \\      |  \  |       \ | |
    |   \ |           |   _//                    \\_    |   \ *         * |
    |     *           |  <_/                      \_>   |     *         | |
    -------------------                                 -------------------

Each developer pulls and pushes to origin.  But besides the centralized
push-pull relationships, each developer may also pull changes from other peers
to form sub teams.  For example, this might be useful to work together with two
or more developers on a big new feature, before pushing the work in progress to
origin prematurely.  In the figure above, there are subteams of Alice and Bob,
Alice and David, and Clair and David.

Technically, this means nothing more than Alice has defined a Git remote, named
bob, pointing to Bob's repository, and vice versa.

-------------------------------------------------------------------------------
BRANCHING MODEL
-------------------------------------------------------------------------------
The model presented here is no more than a set of procedures that every team
member has to follow in order to come to a managed software development process.

| * Represents Commits                                                         |
|                                                                              |
|  _         feat      feat        dev        rel        hot       master      |
|  |T         |          |          |          |          |          |         |
|  |I         |          |          |          |          |        +-* Tag 0.1 |
|  |M         |          |          *<---------|----------|-------/  |         |
|  |E         |          |          |          |          |      /   |         |
|  |  feature for future |          *          |          |     /    |         |
|  |       release       |          |          |          |    /     |         |
|  |          |  ________|_________ *          |          |   /      |         |
|  |          | /        |  /       |          |          |  /       |         |
|  |          *<         | /        *          |          | /        |         |
|  |          |          *<         |          |          |/         |         |
|  |          *  major feature for  |          |          *          |         |
|  |          |     next release    |  ________|________/ | \______  |         |
|  |          |          |          | /        |       severe      \ |         |
|  |          |          *          *<         |       bug fix      >* Tag 0.2 |
|  |          |          |          |          |          |          |         |
|  |          |          *          |          |          |          |         |
|  |          *          |\         |          |          |          |         |
|  |          |          | +------->*_         |          |          |         |
|  |          |          |          | \_____   |          |          |         |
|  |          |          |          |       \  | start of |          |         |
|  | from this point on -------------------->\ | release  |          |         |
|  |   'next release'    |    bugfixes from   >*  branch  |          |         |
|  |  means the release  |     rel branch      |   1.0    |          |         |
|  |      after 1.0      |    continuously     |          |          |         |
|  |          |          |    merge to dev    _*          |          |         |
|  |          |          |          |   _____/ |  only    |          |         |
|  |          |          |          |  /       *  bug     |          |         |
|  |          |          |          | /        |  fixes   |          |         |
|  |          |          |          *<        _*_         |          |         |
|  |          |          |   _____/ |   _____/ | \________|_______   |         |
|  |          |          |  /       |  /       |          |       \  |         |
|  |          |          | /        | /        |          |        \ |         |
|\ | /        *          *<         *<         |          |         >* Tag 1.0 |
| \ /         |\         |          |          |          |          |         |
|  *          | \        *          |          |          |          |         |
|             |  \       |          |          |          |          |         |
|             |   \      *_         |          |          |          |         |
|             |    \     | \_____   |          |          |          |         |
|             |     \____|_______\  |          |          |          |         |
|             |          |        \ |          |          |          |         |
|             |          |         >*          |          |          |         |
|             |          |          |\______   |          |          |         |
|             |          |          |       \  |          |          |         |
|             |          |          |        \ |          |          |         |
|             |          |          |         >*__________|________  |         |
|             |          |          |          |          |        \ |         |
|             |          |          |          |          |         >*         |
|             |          |          |          |          |          |         |

-------------------------------------------------------------------------------
THE MAIN BRANCHES...
-------------------------------------------------------------------------------
At the core, the development model is greatly inspired by existing models out
there. The central repo holds two main branches with an infinite lifetime:
     - master
     - develop (dev)

The master branch at origin should be familiar to every Git user. Parallel to
the master branch, another branch exists called develop.

We consider origin/master to be the main branch where the source code of HEAD
always reflects a production-ready state.

We consider origin/dev to be the main branch where the source code of the HEAD
always reflects a state with the latest delivered development changes for the
next release. Some would call this the “integration branch”. This is where any
automatic nightly builds are built from.

When the source code in the develop branch reaches a stable point and is ready
to be released, all of the changes should be merged back into master somehow
and then tagged with a release number. How this is done in detail will be
discussed further on.

Therefore, each time when changes are merged back into master, this is a new
production release by definition.

-------------------------------------------------------------------------------
SUPPORTING BRANCHES...
-------------------------------------------------------------------------------
Next to the main branches master and dev, our development model uses a variety
of supporting branches to aid parallel development between team members, ease
tracking of features, prepare for production releases and to assist in quickly
fixing live production problems. Unlike the main branches, these branches
always have a limited life time, since they will be removed eventually.

The different types of branches we may use are:
     - Feature branches
     - Release branches
     - Hotfix branches

Each of these branches have a specific purpose and are bound to strict rules as
to which branches may be their originating branch and which branches must be
their merge targets. We will walk through them in a minute.

By no means are these branches “special” from a technical perspective. The
branch types are categorized by how we use them. They are of course plain old
Git branches.

-------------------------------------------------------------------------------
FEATURE BRANCHES
-------------------------------------------------------------------------------
May branch off from:
     dev

Must merge back into:
     dev

Branch naming convention:
     anything except master, dev, rel/*, or hot/*

Feature branches (or sometimes called topic branches) are used to develop new
features for the upcoming or a distant future release. When starting
development of a feature, the target release in which this feature will be
incorporated may well be unknown at that point. The essence of a feature branch
is that it exists as long as the feature is in development, but will eventually
be merged back into develop (to definitely add the new feature to the upcoming
release) or discarded (in case of a disappointing experiment).

Feature branches typically exist in developer repos only, not in origin.


                      CREATING A FEATURE BRANCH

When starting work on a new feature, branch off from the develop branch.

     $ git checkout -b feat/new/my-feature dev
     Switched to a new branch "feat/new/my-feature"


                INCORPORATING A FINISHED FEATURE ON DEV

Finished features may be merged into the dev branch to definitely add them to
upcoming release:

!!IMPORTANT!!

The --no-ff flag causes the merge to always create a new commit object, even if
the merge could be performed with a fast-forward! This avoids losing
information about the historical existence of a feature branch and groups
together all commits that together added the feature!

!!WARNING!!

If --no-ff is not used, it is impossible to see from the Git history which of
the commit objects together have implemented a feature, you would have to
manually read all the log messages! Reverting a whole feature
(i.e. a group of commits), is a true headache in the latter situation, whereas
it is easily done if the --no-ff flag was used.

     $ git checkout dev
     Switched to branch 'dev'

     $ git merge --no-ff feat/vfy/my-feature
     Updating aec23b...02e44f
     (Summary of changes)

     $ git branch -d feat/vfy/my-feature
     Deleted branch feat/vfy/my-feature (was 02e44f).

     $ git push origin dev

-------------------------------------------------------------------------------
RELEASE BRANCHES
-------------------------------------------------------------------------------
May branch off from:
     - dev

Must merge back into:
     - dev and master

Branch naming convention:
     - rel-*

Release branches support preparation of a new production release. They allow
for last-minute dotting of i’s and crossing t’s. Furthermore, they allow for
minor bug fixes and preparing meta-data for a release (version number,
build dates, etc.). By doing all of this work on a release branch, the develop
branch is cleared to receive features for the next big release.

The key moment to branch off a new release branch from develop is when develop
(almost) reflects the desired state of the new release. At least all features
that are targeted for the release-to-be-built must be merged in to develop at
this point in time. All features targeted at future releases may not—they must
wait until after the release branch is branched off.

It is exactly at the start of a release branch that the upcoming release gets
assigned a version number—not any earlier. Up until that moment, the develop
branch reflected changes for the “next release”, but it is unclear whether that
“next release” will eventually become 0.3 or 1.0, until the release branch is
started. That decision is made on the start of the release branch and is
carried out by the project’s rules on version number bumping.


                      CREATING A RELEASE BRANCH

Release branches are created from the develop branch. For example, say version
1.1.5 is the current production release and we have a big release coming up.
The state of develop is ready for the “next release” and we have decided that
this will become version 1.2 (rather than 1.1.6 or 2.0). So we branch off and
give the release branch a name reflecting the new version number:

     $ git checkout -b rel/r1.2 develop
     Switched to a new branch "rel/r1.2"

     $ ./bump-version.sh 1.2
     Files modified successfully, version bumped to 1.2.

     $ git commit -a -m "Bumped version number to 1.2"
     [release-1.2 74d9424] Bumped version number to 1.2
     1 files changed, 1 insertions(+), 1 deletions(-)

After creating a new branch and switching to it, we bump the version number.
Here, bump-version.sh is a fictional shell script that changes some files in
the working copy to reflect the new version. (This can of course be a manual
change—the point being that some files change.) Then, the bumped version number
is committed.

This new branch may exist there for a while, until the release may be rolled
out definitely. During that time, bug fixes may be applied in this branch
(rather than on the develop branch). Adding large new features here is strictly
prohibited. They must be merged into develop, and therefore, wait for the next
big release.


                    FINISHING A RELEASE BRANCH

When the state of the release branch is ready to become a real release, some
actions need to be carried out. First, the release branch is merged into master
(since every commit on master is a new release by definition, remember). Next,
that commit on master must be tagged for easy future reference to this
historical version. Finally, the changes made on the release branch need to be
merged back into develop, so that future releases also contain these bug fixes.

The first two steps in Git:

     $ git checkout master
     Switched to branch 'master'

     $ git merge --no-ff rel/r1.2
     Merge made by recursive.
     (Summary of changes)

     $ git tag -a 1.2

The release is now done, and tagged for future reference.

NOTE: You might want to use the -s or -u <key> flags to sign your tag
cryptographically.

To keep the changes made in the release branch, we need to merge those back
into develop, though. In Git:

     $ git checkout dev
     Switched to branch 'dev'

     $ git merge --no-ff rel/r1.2
     Merge made by recursive.
     (Summary of changes)

!!CAUTION!!

This step may well lead to a merge conflict (probably even, since we have
changed the version number). If so, fix it and commit.

Now we are really done and the release branch may be removed, since we don’t
need it anymore:

     $ git branch -d release-1.2
     Deleted branch release-1.2 (was ff452fe).

-------------------------------------------------------------------------------
HOTFIX BRANCHES
-------------------------------------------------------------------------------
May branch off from:
     master

Must merge back into:
     dev and master

Branch naming convention:
     hot/*

Hotfix branches are very much like release branches in that they are also meant
to prepare for a new production release, albeit unplanned. They arise from the
necessity to act immediately upon an undesired state of a live production
version. When a critical bug in a production version must be resolved
immediately, a hotfix branch may be branched off from the corresponding tag on
the master branch that marks the production version.

The essence is that work of team members (on the develop branch) can continue,
while another person is preparing a quick production fix.


                   CREATING THE HOTFIX BRANCH 

Hotfix branches are created from the master branch. For example, say
version 1.2 is the current production release running live and causing troubles
due to a severe bug. But changes on develop are yet unstable. We may then
branch off a hotfix branch and start fixing the problem:

     $ git checkout -b hotfix-1.2.1 master
     Switched to a new branch "hotfix-1.2.1"

     $ ./bump-version.sh 1.2.1
     Files modified successfully, version bumped to 1.2.1.

     $ git commit -a -m "Bumped version number to 1.2.1"
     [hotfix-1.2.1 41e61bb] Bumped version number to 1.2.1
     1 files changed, 1 insertions(+), 1 deletions(-)

Don’t forget to bump the version number after branching off!

Then, fix the bug and commit the fix in one or more separate commits.

     $ git commit -m "Fixed severe production problem"
     [hotfix-1.2.1 abbe5d6] Fixed severe production problem
     5 files changed, 32 insertions(+), 17 deletions(-)

                  FINISHING THE HOTFIX BRANCH

When finished, the bugfix needs to be merged back into master, but also needs
to be merged back into develop, in order to safeguard that the bugfix is
included in the next release as well. This is completely similar to how release
branches are finished.

First, update master and tag the release.

     $ git checkout master
     Switched to branch 'master'

     $ git merge --no-ff hotfix-1.2.1
     Merge made by recursive.
     (Summary of changes)

     $ git tag -a 1.2.1

Edit: you might as well use the -s or -u <key> flags to sign your tag
cryptographically.

Next, include the bugfix in develop, too:

     $ git checkout develop
     Switched to branch 'develop'

     $ git merge --no-ff hotfix-1.2.1
     Merge made by recursive.
     (Summary of changes)

The one exception to the rule here is that, when a release branch currently
exists, the hotfix changes need to be merged into that release branch, instead
of develop. Back-merging the bugfix into the release branch will eventually
result in the bugfix being merged into develop too, when the release branch is
finished. (If work in develop immediately requires this bugfix and cannot wait
for the release branch to be finished, you may safely merge the bugfix into
develop now already as well.)

Finally, remove the temporary branch:

     $ git branch -d hotfix-1.2.1
     Deleted branch hotfix-1.2.1 (was abbe5d6).

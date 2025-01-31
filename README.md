# Scripts for running builds in Docker containers

## Installation

Simply `git clone` this repository, and place the `bin` directory on
your `$PATH`. If you want to copy the files to another location that's
already on your `$PATH`, be sure to copy all three scripts:
`create-builder`, `enter-builder`, and `builder_entrypoint.sh` to the
same directory.

> [!NOTE]
> These are bash scripts, so they assume `bash` is available on your
> system. They also expect to use the `docker` command, so Docker
> Desktop or Docker Engine must be installed and functional.

## Sample usage

    macbook% create-builder
    Creating empty volume: serverbuild_optcouchbase
    Starting builder with image: couchbasebuild/server-linux-build:latest
    77ea959898a4f3c5df36c7fe7b86d8dae097d64320c5e428495aac1fe347dcb5

    macbook% cd ~/repos/morpheus
    macbook% pwd
    /Users/ceej/repos/morpheus
    macbook% enter-builder
    Entering builder container...
    To exit, type 'exit' or press Ctrl-D.

    bash-4.2$ id
    uid=1000(couchbase) gid=1000(couchbase) groups=1000(couchbase)
    bash-4.2$ pwd
    /Users/ceej/repos/morpheus
    base-4.2$ ./Build.sh
    -- The C compiler identification is GNU 13.2.0
    -- The CXX compiler identification is GNU 13.2.0
    ....

(although, please read the Warning below if you are on a Mac.)

## Details

### `create-builder`

`create-builder` will create a Linux build container with the name
`builder`. Any existing container with that name will first be silently
removed, so you can always just run `create-builder` to get a fresh
start.

By default it uses the Couchbase Server Single Linux build image
`couchbasebuild/server-linux-build:latest`. However you can pass any
Docker image name as an argument to create a different container. In
particular, you may wish to use `couchbasebuild/server-linux-cv:latest`
as it contains some development tools such as valgrind, gdb, and Clang.

> [!TIP]
> The container image should contain at least the following commands on
> the default PATH: `bash`, `getent`, `useradd`, `userdel`, `groupadd`,
> `groupdel`, `chown`, `stty`.

The resulting container will have a user named `couchbase` with UID
1000. That user will have a default group named `couchbase` with GID
1000.

> [!TIP]
> If the container image has `sudo` installed and `/etc/sudoers.d`
> exists, the `couchbase` user will be granted password-less `sudo`
> access. The user's password is `couchbase` if you ever need that
> information.

`create-builder` will also mount your host's user home directory into the
container, with the same path. So, eg., `/Users/ceej` (on a Mac) or
`/home/ceej` (on Linux) will be available at that same path inside the
container. The environment variable `HOSTHOME` in the container will
also be set to that path.

> [!NOTE]
> The `couchbase` user's home directory is `/home/couchbase`, not the
> mounted home directory from the host. So eg. `cd ~` will take you to
> `/home/couchbase` and not `/Users/ceej`. The environment variable
> `$HOME` in the container will always be `/home/couchbase`.

> [!TIP]
> On macOS running Docker Desktop, this mount activity may pop open a
> dialog box requesting permission to access some folders.

### `enter-builder`

You can run the `enter-builder` command from any directory under your
host home directory. This will open a shell inside the container,
running as the `couchbase` user. The working directory inside the
container will be the same path with the same contents, so you can begin
working immediately.

> [!WARNING]
> On a macOS host, there is a significant performance penalty for write
> operations in a container when mounting a directory from the host.
> Please read [the section below](#homecouchbasework-in-the-container)
> entitled "`/home/couchbase/work` in the container".

> [!IMPORTANT]
> Bear in mind that normally, a build directory cannot be used by both
> the host and the `builder` container, particularly when the host is
> macOS. Take care not to run eg. `make` on the host in a directory that
> you previously built in the container.

### Removing the `builder` container

The `builder` container should consume minimal resources when not in
use, but you may always remove it entirely by simply running `docker rm
-f builder`.

## Customizing bash in the container

If you create a file named `~/.docker-bashrc` on your host, it will be
read by `bash` whenever `enter-builder` is run. This allows you to
specify useful aliases, set environment variables such a `$PROMPT`, and
so on.

> [!TIP]
> `enter-builder` will create a file named `~/.docker-bashentry` on the
> host. This can be ignored.

## Notes and Potential Issues

### ssh

`create-builder` will *copy* the contents of your `~/.ssh` directory to
`/home/couchbase/.ssh` in the container. This will allow the `couchbase`
user in the container to have access to your ssh keys, etc. In
particular, you should be able to run commands such as

    ssh git@github.com

> [!NOTE]
> `/home/couchbase/.ssh` in the container is *not* persisted; changes
> you make to these files will not be reflected on the host, and these
> files will be re-created from the host files the next time
> `create-builder` is run.

For `IdentityFile` options in `.ssh/config`, you should use paths like
`~/.ssh/id_rsa` so that they resolve both in the container and on your
host.

If you use any other ssh options that refer to absolute paths, ensure
that they are paths which will work both in the container and on the
host. For example, use

    ControlPath /tmp/ssh-%i-%C

rather than

    ControlPath /run/user/%i/ssh-%C

since `/run/user/xxxx` is unlikely to exist inside the container.

Remember that the `ssh` executable inside the container may be a
different version than what you have on the host, and support different
options. In particular, the `ssh` in `couchbasebuild/server-linux-build`
is quite old, and doesn't recognize the `SetEnv` option. You can put eg.

    IgnoreUnknown SetEnv

before any `SetEnv` options in your `~/.ssh/config` to work around these
kinds of problems.

> [!TIP]
> `create-builder` doesn't ensure that the `ssh` command actually exists
> in the container; that's up the container image. For example, if you
> run `create-builder ubuntu:24.04`, `ssh` won't exist, even though
> `/home/couchbase/.ssh` is ready for it.

### `git` and `repo`

In addition to copying `~/.ssh`, `create-builder` will *copy*
`~/.gitconfig` from the host to `/home/couchbase` in the container.
This, along with the `~/.ssh` directory, should be sufficient to allow
both the `git` and `repo` commands to operate identically.

> [!NOTE]
> With the `couchbasebuild/server-linux-xxxx` images, you may see output
> like `command-line: line 0: Bad configuration option: setenv`
> repeatedly while running `repo sync`. This is because `repo` is using
> ssh options that are too new for the `ssh` in that container image.
> These messages may be ignored; `repo sync` will still succeed.

### `/home/couchbase/work` in the container

As mentioned in a Warning earlier, on a Mac it quite slow to do build
operations in a container in directories mounted from the host.
Therefore if you're on a Mac, you may wish to *not* work inside
`$HOSTHOME` in the container, but instead `cd` to directories under
`/home/couchbase` and run your `repo` and build operations there.

`create-builder` will always mount the container directory
`/home/couchbase/work` from a persistent Docker volume named
`builder_work`, so if you create working directories under there, your
work will be persisted even if you destroy and re-create the `builder`
container. You may also work anywhere else under `/home/couchbase`, but
be aware that any non-mounted directories are transient and will be lost
when the `builder` container is destroyed or re-created.

> [!TIP]
> While there is no performance penalty using directories mounted from
> the host when running on Linux, you may feel free to use
> `/home/couchbase` on Linux as well if you simply don't wish your
> container working directories to appear in your host home directory.
> `/home/couchbase/work` will also be persisted in a Docker volume on
> Linux.

### Cache volumes

`create-builder` also persists the `.ccache`, `.cbdepscache`,
`.cbdepcache`, and `.m2` directories in `/home/couchbase` in the
container, meaning their contents are maintained even when the `builder`
container is destroyed and re-created. This avoids repeated downloads of
cbdeps packages, Maven jars, and so on.

On Linux, when the invoking user's UID is 1000, this persistence is
achieved by mounting the same directories from the host user's home
directory (creating them first if they don't exist) so that the caches
can also be shared with builds on the host.

In other situations, those directories are persisted in Docker volumes
names `builder_ccache`, `builder_cbdepscache`, etc. You will see notes
about these volumes being created the first time you run
`create-builder`.

> [!TIP]
> To see how much space is being used by these `builder_xxxx` Docker
> volumes, run the command `docker system df -v` on the host. These
> volumes can be destroyed by hand if necessary (when the `builder`
> container does not exist) with `docker volume rm build_ccache`, etc.
> They will be re-created, empty, the next time `create-builder` is run.

### `~/.reporef` in the container and on the host

`create-builder` will mount `~/.reporef` from the host (creating it if
it doesn't already exist) to `/home/couchbase/.reporef`.

This can be used as a "reference directory" to speed up `repo sync`
operations, as demonstrated in the following example. The important
things to note are the `--mirror` argument to `repo init` when running
in the `.reporef` directory, and the `--reference=~/.reporef` argument
to `repo init` when running in a working directory.

> [!NOTE]
> These commands may be run on the host or in the container; this
> git-caching technique is not unique to building in Docker.

> [!WARNING]
> On a Mac, it is advisable to run any commands in `~/.reporef` on the
> host to avoid the Docker mounting performance penalty.

    cd ~/.reporef
    repo init -u https://github.com/couchbase/manifest \
        -m couchbase-server/morpheus.xml -g all \
        --mirror
    repo sync -j8     # Takes a long time

    cd /Users/ceej/repos/morpheus
    repo init -u https://github.com/couchbase/manifest \
        -m couchbase-server/morpheus.xml -g all \
        --reference=~/.reporef
    repo sync -j8     # Should take only a few seconds

The second `repo sync` will be much faster, as the vast majority of the
downloaded git information will be re-used.

You can re-run `repo init --mirror` in `~/.reporef` to overlay other
product manifests, and any number of `repo sync` directories may use the
same `--reference=~/.reporef` (including in the `builder` container and
on the host), so this cache can speed up all `repo sync` operations. You
should run `repo sync -j8` in `~/.reporef` every week or two to update
the cached information.

> [!TIP]
> The `~/.reporef` directory is always mounted from the host, even on
> macOS, since git information is not platform-specific. Note that since
> it is in the host home directory as well, it will appear in the
> container at both `$HOME/.reporef` and `$HOSTHOME/.reporef`. On macOS,
> the permissions of these two paths may appear different.

### `docker`

On a Linux host, `create-builder` will mount `/var/run/docker.sock` into
the container, and ensure that the `couchbase` user has appropriate
group permissions to run the `docker` command (should the command exist;
see note about `ssh` above).

On a macOS host, this doesn't work. The Docker socket is at
`${HOME}/.docker/run/docker.sock`, and it's possible to mount that into
the container, but that file's ownership seems to show up as `root:root`
and I could find no way to set up permissions to make it available to
the `couchbase` user (or even to `root`, for that matter). Docker
Desktop on macOS does some fairly esoteric mapping of UIDs and GIDs from
the host filesystem to the container filesystem, based in part on the
host UID that starts the container. PRs gratefully accepted!

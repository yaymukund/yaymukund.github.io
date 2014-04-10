---
layout: post
title:  How to quickly create a read-only Git repository
---

Today, I had to share a git repository to an interview candidate. It's a pain
to grant and revoke access via GitHub, so I decided to host it myself.

A cloned copy of a git repository can itself be cloned. To share a repository
easily, just clone it on your webserver:

```bash how-to-create-a-git-repository.sh
$ ssh my-webserver
$ cd public
$ git clone git@github.com:yaymukund/foo.git --bare foo.git
$ ls
foo.git
$ cd foo.git
$ git update-server-info
```

Now, anyone can clone it:

```bash cloning-a-git-repository.sh
$ git clone http://my-webserver.com/foo.git
```

## Hey, what's with that `update-server-info` stuff?

Good catch! `git` has "smart" repositories and "dumb" repositories. We've
made a dumb repository, which is useful for quickly sharing code. It's not
a good long-term solution. You cannot push to a "dumb" repository easily.

## References

[Git, WebDAV, and basic web hosting](http://stackoverflow.com/a/4203210/1207223)
[Git on the Server - Public Access](http://git-scm.com/book/en/Git-on-the-Server-Public-Access)

---
layout: post
title:  Creating a new app using ember-cli
---

[ember-cli][ember-cli] is a command-line tool for setting up a new Ember.js
application. Creating an application should be familiar to anyone familiar
with Rails.

```bash creating-a-new-app.sh
# Create an app.
$ npm install -g ember-cli
$ ember new myapp

# Build index.html, app.js, app.css to dist/
$ ember build --env <environment>

# Start a watch server.
$ ember server
```

It produces the following directory structure:

```text directory-structure.txt
$ tree -L 2
.
├── Brocfile.js        - Used by Broccoli, Ember's new asset pipeline.
├── api-stub           - Stub routes for tests.
├── app                - Your main Ember application.
├── bower.json         - Specify external dependencies.
├── config
│   └── environment.js - This file produces the `ENV` variable.
├── node_modules
├── package.json
├── public             - Files in this directory get built alongside your app.
├── tests
└── vendor

28 directories, 16 files
```

## Connecting to an API server

The `ember server` command comes with a useful argument that lets you forward
API requests to your server.

```bash forward-requests-to-localhost-3500.zsh
# Any API requests will be proxied to localhost:3500. For example:
#
#   store.find('post', 1)
#
# This would perform a GET http://localhost:3500/posts/1
$ ember server --proxy-port 3500
```

Since it's a proxy, you don't have to worry about CORS or configuring URLs
in the router. It also conveniently lets you host your API on a separate
server.

`ember-cli`'s api is still undergoing rapid development, but if I were
starting a new Ember.js app, it's a good place to start.

[ember-cli]: https://github.com/stefanpenner/ember-cli/

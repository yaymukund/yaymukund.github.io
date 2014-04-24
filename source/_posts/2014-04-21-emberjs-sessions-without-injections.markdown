---
layout: post
title:  Ember.js sessions without injections
---

I had a simple Ember app where I wanted to add authentication. My
requirements were thus:

- A `session` object available to the rest of my application.
- A `/login` route that calls `POST /session`.
- Load the `user` object through a `<meta>` tag if one exists.

## What are the options?

I first looked through some existing examples and libraries. Most of them
use the [injections API](injections-api) to expose the session object. There
are only a few points in my app that interact with the session, so injections
seemed like overkill.

[injections-api]: http://emberjs.com/api/classes/Ember.Application.html#method_inject

## Store the session in a controller

The Ember API documentation advises:

{% blockquote Ember.js Guides http://emberjs.com/guides/controllers/ %}
In general, your models will have properties that are saved to the server,
while controllers will have properties that your app does not need to save to
the server.
{% endblockquote %}

Okay, great, what does this look like?

```javascript app/controllers/session.js
export default Ember.Controller.extend({
  user: null,
  isAuthenticated: Ember.computed.notEmpty('user'),
  loadUser: function(payload) {
    // Load JSON into the store.
    this.store.pushPayload('user', payload);

    // Fetch the user we just loaded without triggering a GET.
    var user = this.store.getById('user', payload.user.id);

    this.set('user', user);
  }
});
```

To fetch the session from a route, [use controllerFor](controller-for)
(`this.controllerFor('session')`). To fetch the session from a controller,
[use the needs API](needs-api) (`needs: ['session']`).

## Add a login route and authenticate method.

Once I had this architecture, stuff fell into place. The route is a standard
route that defines a single authenticate action. Note that the login and
password are neatly kept within the route's controller.

```javascript app/routes/login.js
export default Ember.Route.extend({

  // Redirect if they're already logged in.
  beforeModel: function() {
    var session = this.controllerFor('session');

    if (session.get('isAuthenticated')) {
      this.transitionTo('index');
    }
  },

  actions: {
    authenticate: function() {
      var self = this,
          session = self.controllerFor('session'),
          credentials = {
            login: self.get('controller.login'),
            password: self.get('controller.password')
          };

      $.post('/session', { user: credentials }).then(function(payload) {
        // If a session has a previous transition, retry it. See:
        //
        //   http://goo.gl/Kh0Yx7
        var transition = session.get('previousTransition');
        session.loadUser(payload);

        if (transition) {
          transition.retry();
        } else {
          self.transitionTo('index');
        }
      });
    }
  }
});
```

## Loading the session from a `<meta>` tag

If the user has an existing session when they load the page, the server might
write a `<meta>` tag with the current user object. For example:

```html index.html
<meta name="current-user" content="{ user: { id: 1, login: 'yaymukund' }}">
```

I loaded this session information when the app starts in the `beforeModel` hook
of the `ApplicationRoute` itself:

```javascript app/routes/application.js
export default Ember.Route.extend({
  beforeModel: function(transition) {
    var session = this.controllerFor('session'),
        json = $('meta[name="current-user"]').attr('content');

    if (json) {
      session.loadUser(JSON.parse(json));
    }
  }
});
```

## Bonus! - Adding an authenticated route

With these routes in place, it's simple to restrict access to parts of the
application:

```javascript app/routes/members-only.js
export default Ember.Route.extend({
  beforeModel: function(transition) {
    var session = this.controllerFor('session');

    if (!session.get('isAuthenticated')) {
      session.set('previousTransition', transition);
      this.transitionTo('login');
    }
  }
});
```

[needs-api]: http://emberjs.com/guides/controllers/dependencies-between-controllers/
[controller-for]: http://emberjs.com/api/classes/Ember.Route.html#method_controllerFor

## References

A big thanks to [Alex Speller](http://alexspeller.com/) for tirelessly
answering my questions on IRC.

- [Complex Architectures in Ember](http://madhatted.com/2013/8/31/emberfest-presentation-complex-architectures-in-ember)
- [Ember.js Guides - The needs API](http://emberjs.com/guides/controllers/dependencies-between-controllers/)
- [Ember.js API - controllerFor](http://emberjs.com/api/classes/Ember.Route.html#method_controllerFor)

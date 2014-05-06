# Description #
This is a simple postgres-powered implementation of a forum using
[this model](http://defanor.uberspace.net/notes/a-conversation-model.html). It's
far from polished, and most likely will be rewritten completely if
it'll come to a production version, but it's enough to play with it.

[dagre-d3](https://github.com/cpettitt/dagre-d3) is slightly modified
here, in order to make nodes clickable.

# Installation #
1. clone the repository
2. `cabal install`
3. set postgres user/host/db in
   `snaplets/postgresql-simple/devel.cfg`, add `authTable = "users"` there
4. `postforum -p 8000` to run it and create the `users` table
5. create the `messages` table:

        create table messages (
          id serial primary key,
          uid integer not null references users(uid),
          creation_time timestamp not null default current_timestamp,
          topics integer[] not null,
          restrictions integer[] not null,
          root integer not null references messages(id),
          parent integer references messages(id),
          message text not null
        );
        
        create index restrictions_idx on messages using gin(restrictions);
        create index topics_idx on messages using gin(topics);


The site should be available at [localhost:8000](http://localhost:8000).

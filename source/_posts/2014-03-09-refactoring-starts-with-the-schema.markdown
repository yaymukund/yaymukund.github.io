---
layout: post
title:  Refactoring starts with the schema
---

I was designing a database schema for a Radio `Playlist` that contains many
`Track`s. When a `User` joins a playlist, they hear each track in order. If
they close their browser mid-song, we'd remember the song and start again with
that song when they returned.

My first attempt to design tracks went something like this:

```ruby db/migrate/20140217211534_create_tracks.rb
class CreateTracks < ActiveRecord::Migration
  def change
    create_table :tracks do |t|
      t.text :url
      t.text :filetype
      t.integer :track_order, null: false
      t.datetime :added_at
      t.boolean :playing
      t.references :playlist, index: true
      t.timestamps
    end
  end
end
```

Since we're playing playlist tracks in order, I needed an index on
`track_order` scoped to the playlist.

```ruby db/migrate/20140217211534_create_tracks.rb#index
def change
  # ...
  add_index(:tracks, [:playlist_id, :track_order], order: { track_order: :asc })
end
```

That was a good start. Next, I decided to write a `play_next_track!` method on
the playlist:

```ruby app/models/playlist.rb

class Playlist < ActiveRecord::Base
  has_many :tracks, -> { order('tracks.track_order ASC') } do
    def current
      playing.first
    end

    def next
      if current.present?
        where(
          'tracks.track_order > ?', current.track_order
        ).first
      else
        first
      end
    end
  end

  def play_next_track!
    def play_next_track!
      current_track, next_track = tracks.current, tracks.next

      next_track.playing = true if next_track.present?
      current_track.playing = false if current_track.present?

      Track.transaction do
        current_track.try(:save)
        next_track.try(:save)
      end
    end
  end
end
```

This is pretty hairy code. Fetching the next track is tricky because it
depends on whether or not there's a current track. I also needed to wrap the
track change in a transaction to avoid a race-condition.

## Fixing the database schema

I decided to ditch the `playing` boolean field for a `played_at` datetime field
and it magically solved all my problems.

```ruby app/models/playlist.rb
class Playlist < ActiveRecord::Base
  has_many :tracks, -> { order('tracks.track_order ASC') }

  def play_next_track!
    current_track = tracks.unplayed.first
    current_track.played_at = Time.now
    current_track.save
  end
end
```

I no longer need to worry about updating `playing=true` in a transaction,
finding the next track is just a matter of
`tracks.order('track_order ASC').where(played_at: nil).first`. As a bonus, I
can also easily check `played_at` to see if a track's been played.

The right database schema makes bugs impossible at the lower levels of your
architecture.

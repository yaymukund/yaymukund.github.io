---
layout: post
title:  Ranked-model and uniqueness constraints
---

I've been playing with the gem [ranked-model][], which seems to be a promising
sorting gem for Rails. It lets you manage lists of Rails models sorted by
some integer column. I wanted to have a playlist of tracks, each with a
position in the playlist:

```ruby app/models/track.rb
class Track < ActiveRecord::Base
  belongs_to :playlist

  # `with_same` will scope the track numbers to the playlist.
  ranks :track_order, with_same: :playlist_id
end
```

I wanted database-level protection, so I added a Postgres uniqueness constraint:

```ruby db/migrate/20140217211534_create_tracks.rb
class CreateTracks < ActiveRecord::Migration
  def change
    # ...
    reversible do |direction|
      direction.up do
        execute <<-SQL
          ALTER TABLE tracks
            ADD CONSTRAINT index_tracks_on_playlist_id_and_track_order
            UNIQUE (playlist_id, track_order);
        SQL
      end

      direction.down do
        execute <<-SQL
          ALTER TABLE tracks
            DROP CONSTRAINT IF EXISTS index_tracks_on_playlist_id_and_track_order;
        SQL
      end
    end
  end
end
```

Looks great! When I ran my tests, though, they failed:

```ruby rspec failure
...FFFF.............

Failures:

  1) TracksController POST /tracks creates a metadata
     Failure/Error: post :create, track: {
     ActiveRecord::RecordNotUnique:
       PG::UniqueViolation: ERROR:  duplicate key value violates unique
       constraint "index_tracks_on_playlist_id_and_track_order"
       DETAIL:  Key (playlist_id, track_order)=(27, 8388606) already exists.
       : UPDATE "tracks" SET track_order = track_order - 1 WHERE "tracks"."id"
       IN (SELECT "tracks"."id" FROM "tracks"  WHERE "tracks"."playlist_id" =
       27 AND ("tracks"."track_order" <= 8388607)  ORDER BY
       "tracks"."track_order" ASC)
     # ./app/controllers/tracks_controller.rb:6:in `create'
```

After banging my head a bit, I finally figured it out. Internally,
`ranked-model` sets `track_order_position` to some number between
-8388607 and 8388607, the `MEDIUMINT` range in MySQL. This is all
[explained in the ranked-model documentation][ranked-model-internals]. It's a
clever and effective way to avoid constantly rearranging records.

Sometimes, it *does* need to rearrange records, though. When it does, it
calls `rearrange_ranks`:

```ruby lib/ranked-model/ranker.rb https://github.com/mixonic/ranked-model/blob/fad88ca2a31d804c4af083c8199c83ee5c5e5d48/lib/ranked-model/ranker.rb#L171-193
def rearrange_ranks
  _scope = finder
  unless instance.id.nil?
    # Never update ourself, shift others around us.
    _scope = _scope.where( instance_class.arel_table[instance_class.primary_key].not_eq(instance.id) )
  end
  if current_first.rank && current_first.rank > RankedModel::MIN_RANK_VALUE && rank == RankedModel::MAX_RANK_VALUE
    _scope.
      where( instance_class.arel_table[ranker.column].lteq(rank) ).
      update_all( %Q{#{ranker.column} = #{ranker.column} - 1} )
  elsif current_last.rank && current_last.rank < (RankedModel::MAX_RANK_VALUE - 1) && rank < current_last.rank
    _scope.
      where( instance_class.arel_table[ranker.column].gteq(rank) ).
      update_all( %Q{#{ranker.column} = #{ranker.column} + 1} )
  elsif current_first.rank && current_first.rank > RankedModel::MIN_RANK_VALUE && rank > current_first.rank
    _scope.
      where( instance_class.arel_table[ranker.column].lt(rank) ).
      update_all( %Q{#{ranker.column} = #{ranker.column} - 1} )
    rank_at( rank - 1 )
  else
    rebalance_ranks
  end
end
```

The details of this code aren't important, but notice that it sometimes
calls `update_all` to increment or decrement a group of records. This triggers
Postgres's uniqueness constraint and the record fails validation.

To fix this, we need to make the uniqueness constraint *deferrable*:

```ruby db/migrate/20140217211534_create_tracks.rb
ALTER TABLE tracks
  ADD CONSTRAINT index_tracks_on_playlist_id_and_track_order
  UNIQUE (playlist_id, track_order) DEFERRABLE INITIALLY IMMEDIATE;
```

And then we actually need to defer the constraint when rearranging records:

```ruby app/models/track.rb
class Track < ActiveRecord::Base
  before_save :defer_uniqueness_constraint_if_track_order_changed

  private

  def defer_uniqueness_constraint_if_track_order_changed
    if new_record? or track_order_changed?
      self.class.connection.execute <<-SQL
        SET CONSTRAINTS
          index_tracks_on_playlist_id_and_track_order DEFERRED;
      SQL
    end
  end
end
```

And suddenly, all my tests passed. Hooray!

## References

* http://hashrocket.com/blog/posts/deferring-database-constraints
* https://github.com/mixonic/ranked-model
* http://www.postgresql.org/docs/9.3/static/sql-set-constraints.html

[ranked-model]: https://github.com/mixonic/ranked-model
[ranked-model-internals]: https://github.com/mixonic/ranked-model#internals
[rearrange-ranks]:https://github.com/mixonic/ranked-model/blob/fad88ca2a31d804c4af083c8199c83ee5c5e5d48/lib/ranked-model/ranker.rb#L171

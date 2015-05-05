Rails and SQL
=============

Paul A. Jungwirth

PDX.rb

May 2015


[//]: # (Thanks for coming!)
[//]: # (My name is Paul Jungwirth.)
[//]: # (I do software development and consulting in the Portland area.)
[//]: # (I specialize in Rails, Postgres, and Chef. I've also done some iOS and Machine Learning.)



Plan
====

- Interesting things you can do in SQL.
  - With Postgres (sometimes portable).
  - Inside Rails.

[//]: # (I'll start with beginner stuff, quickly get into advanced stuff.)
[//]: # (Sorry, no Arel!)
[//]: # (First I'll show the SQL.)
[//]: # (Then I'll show how to use it in Rails.)
[//]: # (One of my goals is to show that even with an ORM, you can do non-trivial queries.)
[//]: # (Show of hands: know what an outer join is?)
[//]: # (Show of hands: know the difference between right and left?)
[//]: # (Show of hands: know the difference between where and having?)



Inspections Schema
==================


    restaurants --< inspections --< violations
    -----------     -----------     ----------
    id              id              id
    name            restaurant_id   inspection_id
                    score           name
                    inspected_at

<!-- -->

    r.name       i.score  i.inspected_at   v.name
    ------       -------  --------------   ------
    Bob's Diner       77      2015-01-07   Rats
    Bob's Diner       71      2015-01-15   Rats
    Bob's Diner       71      2015-01-15   Zombies
    Bob's Diner       75      2015-03-15   Bats
    Joe's Place 
    Crystal Palace   100      2015-01-07

Courtesy of Robb Schecter at eaternet.io.

[//]: # (Tonight I'll use restaurant inspections for my example schema.)
[//]: # (I want to thank Robb Schecter for letting me use this from his site eaternet.io.)
[//]: # (This talk really started with a question he asked on the mailing list.)
[//]: # (So it's got 3 tables....)
[//]: # (Restaurants have many inspections, they have many violations.)
[//]: # (Sample data below.)
[//]: # (Note that Joe's Place has no inspections yet!)



SQL: Easy Stuff
===============

    @@@sql
    SELECT  id, name
    FROM    inspections
    WHERE   score > 80
    ORDER BY inspected_at DESC

<!-- -->

    @@@sql
    SELECT  date_trunc('month', inspected_at) AS m,
            MAX(score) AS winner
    FROM    inspections
    GROUP BY m
    HAVING  MAX(score) > 90
    ORDER BY m

[//]: # (A SQL statement has a SELECT and a FROM: ask for these columns from that table)
[//]: # (Optionally a WHERE to filter things, and ORDER BY to order things.)

[//]: # (Functions like date_trunc.)
[//]: # (AS to create an alias for a column or table.)

[//]: # (GROUP BY transforms the results from one-row-per-record to a summary.)
[//]: # (    summarizing by inspection month. MAX is an "aggregate function".)
[//]: # (    Here we want the top score for each month.)
[//]: # (    Maybe to pick a winner for a prize!)

[//]: # (Whereas WHERE lets you filter before summarizing, HAVING lets you filter afterward.)
[//]: # (    No winner if no one got a 90.)




ActiveRecord: Easy Stuff
========================

    @@@ruby
    @inspections = Inspection.where("score > 80").
                              order(inspected_at: :desc)

    @violations = @inspection.violations.where(name: "Rats")

    puts @inspection.violations.where(name: "Rats").to_sql


[//]: # (Get inspections with score more than 80, most recent first.)
[//]: # (Get all the rat violations.)
[//]: # (Use .to_sql to see what ActiveRecord is doing for you.)




ActiveRecord where
==================

    @@@ruby
    Inspection.where(score: 90)
    Inspection.where("score > ?", 90)
    Inspection.where("inspections.score > ?", 90)

    Restaurant.where(name: "This is safe")
    Restaurant.where("name = ?", "Still safe")
    Restaurant.where("name = '#{oops}'")

[//]: # (Lots of ways to use `where`.)
[//]: # (String, hash, string with question marks.)
[//]: # (Okay to qualify your columns if your query has several tables.)

[//]: # (Rails protects you from SQL injection.)
[//]: # (  I assume you know what SQL injection is.)
[//]: # (  You don't want your users sending you SQL code.)


SQL joins: INNER vs OUTER
=========================

[//]: # (So how to combine tables? That's where all the interesting stuff happens.)
[//]: # (Called a join.)

    @@@sql
    SELECT  *
    FROM    restaurants r
    INNER JOIN inspections i
    ON      i.restaurant_id = r.id

<!-- -->

    @@@sql
    SELECT  *
    FROM    restaurants r
    LEFT OUTER JOIN inspections i
    ON      i.restaurant_id = r.id

- JOIN *table* ON *condition*

- INNER JOIN throws away rows with no match.
- LEFT OUTER JOIN constructs all-NULL rows if no match.
  - Ensures we get *all* restaurants,
    not just those with an inspection.
[//]: # (Also RIGHT OUTER JOIN and FULL OUTER JOIN, but ignore those.)
[//]: # (LEFT OUTER JOIN gives you at least one row in your FROM table.)

- Where to start??
  [//]: # (SQL is challenging because it's not imperative.)
  - From the `FROM`.
  - What is each row of the result?




ON vs WHERE: inner join
=======================

Equivalent with inner joins:

    @@@sql
    SELECT  *
    FROM    restaurants r
    INNER JOIN inspections i
    ON      i.restaurant_id = r.id
    AND     i.score > 80

equals:

    @@@sql
    SELECT  *
    FROM    restaurants r
    INNER JOIN inspections i
    ON      i.restaurant_id = r.id
    WHERE   i.score > 80

[//]: # (Both are filters, right?)
[//]: # (Match up all restaurants and all inspections, throw out those that fail.)




ON vs WHERE: outer join
=======================

Different with outer joins!

    @@@sql
    SELECT  *
    FROM    restaurants r
    LEFT OUTER JOIN inspections i
    ON      i.restaurant_id = r.id
    AND     i.score > 80

returns more rows than:

    @@@sql
    SELECT  *
    FROM    restaurants r
    LEFT OUTER JOIN inspections i
    ON      i.restaurant_id = r.id
    WHERE   i.score > 80

1. Apply the `ON` fitlers.
2. Add `NULL` rows where necessary.
3. Apply the `WHERE` filters.

[//]: # (ON will never drop restaurants.)
[//]: # (WHERE can.)
[//]: # (Top: match inspections with a good score.)
[//]: # (Bottom: match restaurants with a good score.)




Too many OUTER JOINs
====================
[//]: # (Very skippable.)

    @@@sql
    SELECT  r.name,
            AVG(i.score)
    FROM    restaurants r
    LEFT OUTER JOIN inspections i
    ON      i.restaurant_id = r.id
    LEFT OUTER JOIN violations v
    ON      v.inspection_id = i.id
    GROUP BY r.id

- `AVG` will be wrong.
- A --< **B** --< C
- **B** >-- A --< **C**

[//]: # (When grouping, you're only allowed **one** OUTER JOIN that matches 2+ rows.)




ActiveRecord joins
==================

`joins` gives an inner join:

    @@@ruby
    @good_restaurants = Restaurant.joins(:inspections).
                                   where("inspections.score > ?", 80)


- only restaurants with an inspection
- only restaurants with an 80+ score
- avoids the "n+1" problem:

<!-- -->

    @@@haml
    - @good_restaurants.each do |r|
      %li= r.name + ": " + r.inspections.first.score
  



ActiveRecord includes
=====================

`includes` gives a LEFT OUTER JOIN (in effect):

    @@@ruby
    @restaurants = Restaurant.includes(:inspections)
                           # .where("inspections.score > ?", 80)
  
might produce:

    @@@sql
    SELECT  *
    FROM    restaurants
    LEFT OUTER JOIN inspections
    ON      inspections.restaurant_id = restaurants.id
    WHERE   

- But don't depend on it!
- Sometimes runs a second query.
  [//]: # (Just get all the inspections whose restaurant_id is 1, 2, 3, ....)
- Either way avoids the "n+1" problem.

[//]: # (I don't know how Rails decides. Anyone know?)




Extra attributes with select
============================

    @@@ruby
    class Restaurant
      def inspections_with_violation_counts
        inspections.
          select("inspections.*").
          select("COUNT(violations.id) AS violations_count").
          joins(<<-EOQ).
            LEFT OUTER JOIN violations
            ON violations.inspection_id = inspections.id
          EOQ
          group("inspections.id")
      end 
    end

[//]: # (Step through it!)
  [//]: # (given a restaurant, get its inspections, along with a count of violations.)
  [//]: # (select all the normal stuff)
  [//]: # (also select the violation count: COUNT() is an aggregate function.)

  [//]: # (left join.)
  [//]: # (heredoc!!! quotes everything until your token appears again.)

  [//]: # (grouping)

- Messy? So why use ActiveRecord at all?
  - scopes: composable query logic
  - instance methods
  - compat, e.g. will_paginate




Raw SQL to Models
=================

[//]: # (It's always good to have an escape hatch.)

    @@@ruby
    Inspection.find_by_sql([<<-EOQ, 1.2])
      SELECT  *,
              score * ? AS curved_score
      FROM    inspections
    EOQ

- Returns Inspection instances.
- Computed columns okay.
- `?` params okay but requires `[]`.
- Named `:foo` params okay too.




Raw SQL
=======

[//]: # (Even more of an escape hatch!)

    @@@ruby
    connection.select_rows("SELECT a, b FROM bar")
    # [["1","2"], ["4","5"]]

    connection.select_all("SELECT a, b FROM bar")
    # #<ActiveRecord::Result:0x007ff34710a5f8>

    connection.select_all("SELECT a, b, c FROM bar").to_a
    # [{"a"=>"1", "b"=>"2"}, {"a"=>"4","b"=>"5"}]

- Or `ActiveRecord::Base.connection` outside models and migrations.
- No instances: sometimes arrays, sometimes Results.
- Every scalar is a string.




Raw SQL 2
=========

    @@@ruby
    connection.select_values("SELECT id FROM inspections")
    # ["1", "4"]

    connection.select_value("SELECT MIN(id) FROM inspections")
    # ["1"]

    connection.select_one("SELECT MIN(id) AS id FROM inspections")
    # {"id"=>"1"}




Raw SQL quoting
===============

[//]: # (With raw queries you have to deal with quoting.)

    @@@ruby
    connection.select_rows <<-EOQ
      SELECT  id, name
      FROM    inspections
      WHERE   name = '#{connection.quote_string(foo)}'
      OR      id = #{bar.to_i}
    EOQ

- SQL Injection?!
  - `execute`, `select_*`, `joins`: no `?` params
  - Always know from reading only the method body that it's safe.
  - Use `quote_string` or `to_i` to avoid SQLi.
  [//]: # (foo.to_i.to_i is safe.)




Simple `scope`
==============
  
[//]: # (Now that we've seen the escape hatches, let's see what we can do without them.)
[//]: # (One cool way to embed fancy SQL into AR is scopes.)

    @@@ruby
    class Inspection

      scope :passing, where("score > 80")

      scope :between, -> {|start_day, end_day|
        where("inspected_at BETWEEN ? AND ?", start_day, end_day)
      }

    end

- static or dynamic
- composable




Correlated Subqueries
=====================

[//]: # (Here's some fancy SQL we might want to use.)
[//]: # (Correlated subquery: let's you run a subquery for each row.)
  [//]: # (. . . conceptually: The optimizer will probably be smarter than that.)

All restaurants with no inspections yet:

    @@@sql
    SELECT  *
    FROM    restaurants r
    WHERE   NOT EXISTS (SELECT  1
                        FROM    inspections i
                        WHERE   i.restaurant_id = r.id)

- Faster than `NOT IN`.
- Less constraining than a join.
  [//]: # (Still querying just the restaurants table. No extra rows.)




Subqueries with `scope`
=======================

    @@@ruby
    scope :without_inspection, -> {
      where(<<-EOQ)
        NOT EXISTS (SELECT  1
                    FROM    inspections i
                    WHERE   i.restaurant_id = restaurants.id)
      EOQ
    }

[//]: # (In earlier Rails, you could leave out the lambda.)




Merging scopes
==============

[//]: # (Reuse across tables)

    @@@ruby
    class Inspection
      scope :perfect, -> { where(score: 100) }
    end

    class Restaurant
      scope :with_a_perfect_score, -> {
        joins(:inspections).merge(Inspection.perfect)
      }
    end

- Lets you compose scopes from other models.
- Could have been an `EXISTS` to avoid the join.
- Which is more flexible?




Time Series with naive GROUP BY
===============================

Count the inspections in each month of 2015:

    @@@sql
    SELECT  EXTRACT('MONTH' FROM inspected_at) m,
            COUNT(*)
    FROM    inspections
    WHERE   EXTRACT('YEAR' FROM inspected_at) = 2015
    GROUP BY m
    ORDER BY m

- Excludes months with zero inspections!




Time Series with generate_series
================================

[//]: # (generate_series is a "set-returning function".)
[//]: # (It gives you a whole table: named s w/ 1 column m.)
[//]: # (We use it to get 12 months.)
[//]: # (Then we use BETWEEN to collect everything.)

    @@@sql
    SELECT  s.m + 1 AS month,
            COUNT(id)
    FROM    generate_series(0, 11) s(m)
    LEFT OUTER JOIN inspections
    ON      inspected_at
            BETWEEN '2015-01-01'::date + (s.m || ' MONTHS')::interval
            AND     '2015-01-01'::date + ((s.m + 1) || ' MONTHS')::interval
                                       - INTERVAL '1 DAY'
    GROUP BY s.m
    ORDER BY s.m

- Start with `FROM`: each output row is a month.

[//]: # (Now how are we going to do this in Rails??)




generate_series in `from`
=========================

[//]: # (The answer is `from`)

    @@@ruby
    class Restaurant
      def inspections_per_month(year)
        Inspection.
          select("s.m + 1 AS inspection_month").
          select("COUNT(inspections.id) AS inspections_count").
          from("generate_series(0, 11) s(m)").
          joins(<<-EOQ).
            LEFT OUTER JOIN inspections
            ON  inspections.inspected_at
                BETWEEN '#{year.to_i}-01-01'::date
                        + (s.m || ' MONTHS')::interval
                AND     '#{year.to_i}-01-01'::date
                        + ((s.m + 1) || ' MONTHS')::interval
                        - INTERVAL '1 DAY'
            AND inspections.restaurant_id = #{id.to_i}
          EOQ
          group("inspection_month").
          order("inspection_month")
      end
    end

- `from` to override the normal table.
- join to the inspections table so we have it.
- Or `RIGHT OUTER JOIN`
  [//]: # (But I promised I wouldn't talk about that.)
- Possible to say `inspections` rather than `Inspection`?
  [//]: # (No, that adds `WHERE restaurant_id = 1` and it kills months with no inspections.)
[//]: # (Tempted to use find_by_sql here to reduce the noise.)




generate_series CTE
===================

[//]: # (Skippable...)
[//]: # (But we can also clean it up with a CTE!)

CTE: Common Table Expression

    @@@sql
    WITH t(month) AS (
      SELECT  '2015-01-01'::date + (s.m || ' MONTHS')::interval
      FROM    generate_series(0, 11) s(m)
    )
    SELECT  t.month,
            COUNT(id)
    FROM    t
    LEFT OUTER JOIN inspections
    ON      inspected_at BETWEEN month AND month + INTERVAL '1 MONTH' - INTERVAL '1 DAY'
    GROUP BY month
    ORDER BY month

- Pull out a subquery and give it a name.
- Not just sugar: also "optimization fence".
  - Bad if you load a whole table.
  - Good for `INSERT`, `UPDATE`, one-time functions.
- `RECURSIVE`: tree-like stuff.




generate_series in `with`
=========================

[//]: # (Skippable...)

- Can't use `WITH` in ActiveRecord.
- Use the `postgres_ext` gem.
    
<!-- -->

    @@@ruby
    Inspection.
      with("t(month)" => <<-EOQ).
        SELECT  '2015-01-01'::date + (s.m || ' MONTHS')::interval
        FROM    generate_series(0, 11) s(m)
      EOQ
      select("t.month").
      select("COUNT(inspections.id) AS inspections_count").
      from("t").
      joins(<<-EOQ).
        LEFT OUTER JOIN inspections
        ON  inspections.inspected_at BETWEEN t.month
                                     AND t.month + INTERVAL '1 MONTH'
                                                 - INTERVAL '1 DAY'
        AND inspections.restaurant_id = #{id.to_i}
      EOQ
      group("t.month").
      order("t.month")




Score of most recent inspection
===============================

- Get the list of restaurants.
- Include the score of the *just one* inspection.
- Avoid n+1 queries
- Include restaurants with no inspections yet.




Grouping and aggregates
=======================

Define a `FIRST` aggregate function:

[//]: # (Intuitively it seems like this is a GROUPing situation.)
[//]: # (Plan: group by restaurant id, pick the first inspection.)
[//]: # (No FIRST function, so we'll create one.)
[//]: # (Shown as a Rails migration.)
[//]: # (First we define the function, then we declare it as an aggregate.)
[//]: # (Skip the details.)

    @@@ruby
    def up
      # https://wiki.postgresql.org/wiki/First/last_%28aggregate%29

      connection.execute <<-EOQ
        CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
        RETURNS anyelement LANGUAGE sql IMMUTABLE STRICT AS $$
        SELECT $1;
        $$;
      EOQ

      connection.execute <<-EOQ
        CREATE AGGREGATE public.first (
          sfunc    = public.first_agg,
          basetype = anyelement,
          stype    = anyelement
        );
      EOQ
    end




Grouping and aggregates
=======================

[//]: # (Here we put the FIRST function to use.)

    @@@ruby
    scope :with_latest_score, -> {
      select("restaurants.*").
        select(<<-EOQ).
          FIRST(
            inspections.score
            ORDER BY inspections.inspected_at DESC
          ) AS latest_score
        EOQ
        joins(<<-EOQ).
          LEFT OUTER JOIN inspections
          ON inspections.restaurant_id = restaurants.id
        EOQ
        group("restaurants.id")
    }

- Any aggregate function permits `ORDER BY`.
- Forces a join and grouping: less composable.

[//]: # (FIRST only lets you get one column at a time.)




Latest score with Lateral Joins
===============================

[//]: # (LATERAL joins introduced in Postgres 9.3.)
[//]: # (Keyword after a JOIN.)

    @@@sql
    SELECT  r.name,
            latest.inspected_at,
            latest.score
    FROM    restaurants r
    LEFT OUTER JOIN LATERAL (
      SELECT  *
      FROM    inspections i
      WHERE   i.restaurant_id = r.id
      ORDER BY i.inspected_at DESC
      LIMIT 1
    ) latest
    ON true
    ORDER BY latest.score DESC NULLS LAST
                        
- Evaluated once for each outer row.
- `ON` is a formality.
- Fast?
- Doesn't change the query's cardinality/structure.




Lateral Joins in Rails
======================

    @@@ruby
    Restaurant.
      select(:name).
      select("latest.inspected_at AS latest_inspected_at").
      select("latest.score AS latest_score").
      joins(<<-EOQ).
        LEFT OUTER JOIN LATERAL (
          SELECT  *
          FROM    inspections i
          WHERE   i.restaurant_id = restaurants.id
          ORDER BY i.inspected_at DESC
          LIMIT 1
        ) latest
        ON true
      EOQ
      order("latest.score DESC NULLS LAST")

- Nothing really new here.
- Easy to factor the `joins` into a scope.




Window functions
================

Compare each inspection score
to that restaurant's average score:

    @@@sql
    SELECT  i.inspected_at,
            r.name,
            i.score,
            AVG(i.score) OVER (PARTITION BY i.restaurant_id)
    FROM    inspections i
    INNER JOIN restaurants r
    ON      r.id = i.restaurant_id
    ORDER BY i.inspected_at, r.name

- Lets you compute a function on a partition of the result, independent of the overall query structure.
- PARTITION BY to define groups like GROUP BY.
- No query-wide GROUP BY necessary!
- Also `rank`, `ntile`, etc.
- Easy to throw this into an ActiveRecord `select`.




Latest score by Window functions
================================

    @@@sql
    WITH latest AS (
      SELECT  restaurant_id,
              rank() OVER (
                PARTITION BY restaurant_id
                ORDER BY inspected_at DESC
              ) AS rank,
              first_value(score) OVER (
                PARTITION BY restaurant_id
                ORDER BY inspected_at DESC
              ) AS score
      FROM    inspections
    )
    SELECT  r.name,
            latest.score
    FROM    restaurants r
    LEFT OUTER JOIN latest
    ON      latest.restaurant_id = r.id
    AND     latest.rank = 1
    ORDER BY latest.score

- CTE just for cleanliness and fun. But slower?
- No window functions in WHERE (`latest.rank` has to be outside the CTE/subquery).
- Nothing new here for Rails.




More
====

- recursive CTEs

- more on window functions

- json
  - tags
  - migrations
  - `serialize`: Rails 3 vs 4

- hstore
  - faceted search
  - GIN and GiST indexes

- arrays

- Rails migrations

- INSERT INTO . . . RETURNING




Thank You!
==========

Read More:

- Postgres docs!: http://www.postgresql.org/docs/9.4/static/index.html
- Joins: http://www.postgresql.org/docs/9.4/static/queries-table-expressions.html
- CTEs: http://www.postgresql.org/docs/9.4/static/queries-with.html
- Window Functions: http://www.postgresql.org/docs/9.4/static/tutorial-window.html



Rails and SQL
=============

Paul A. Jungwirth

PDX.rb

May 2015



TODO
====

- Interesting things you can do in SQL.
  - With Postgres.
  - Inside Rails.



Inspections Schema
==================


    restaurants --< inspections --< violations
    -----------     -----------     ----------
    name            score           name
                    inspected_at

Courtesy of Robb Schecter at eaternet.io.



SQL: Easy Stuff
===============

    @@@sql
    SELECT  *
    FROM    inspections
    WHERE   score > 80
    ORDER BY inspected_at DESC

    @@@sql
    SELECT  date_trunc('month', inspected_at) AS m,
            MAX(score) AS winner
    FROM    inspections
    GROUP BY m
    HAVING  MAX(score) > 90
    ORDER BY m



ActiveRecord: Easy Stuff
========================

    @@@ruby
    @inspections = Inspection.where("score > 80").
                              order(inspected_at: :desc)

    @violations = @inspection.violations.where(name: "Rats")



ActiveRecord where
==================

    @@@ruby
    Inspection.where(score: 90)
    Inspection.where("score > ?", 90)
    Inspection.where("inspections.score > ?", 90)

    Restaurant.where(name: "This is safe")
    Restaurant.where("name = ?", "Still safe")
    Restaurant.where("name = '#{oops}'")



SQL joins: INNER vs OUTER
=========================

    @@@sql
    SELECT  *
    FROM    restaurants r
    INNER JOIN inspections i
    ON      i.restaurant_id = r.id

    @@@sql
    SELECT  *
    FROM    restaurants r
    LEFT OUTER JOIN inspections i
    ON      i.restaurant_id = r.id

- ensures we get *all* restaurants,
  not just those with an inspection.


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

Null rows are added *after* the `ON`.
Filtering with `WHERE` happens *after* the join.


ActiveRecord joins
==================

`joins` gives an inner join:

    @@@ruby
    @good_restaurants = Restaurant.joins(:inspections).
                                   where("inspections.score > ?", 80)


    - only restaurants with an inspection
    - only restaurants with an 80+ score
    - avoids the "n+1" problem
  

ActiveRecord includes
=====================

`includes` gives a left outer join (in effect):

    @@@ruby
    @restaurants = Restaurant.includes(:inspections).
                            # where("inspections.score > ?", 80)
  
might produce:

    @@@sql
    SELECT  *
    FROM    restaurants
    LEFT OUTER JOIN inspections
    ON      inspections.restaurant_id = restaurants.id
    WHERE   

- But don't depend on it!
- Sometimes runs a second query.
- Either way avoids the "n+1" problem.



Extra attributes with select
============================

    @@@ruby
    class Restaurant
      # . . .
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


- why use ActiveRecord at all?
  - scopes: composable query logic
  - instance methods
  - compat, e.g. will_paginate


Raw SQL
=======

    @@@ruby
    connection.select_rows("SELECT a, b FROM bar")
    # [["1","2"], ["4","5"]]

    connection.select_all("SELECT a, b FROM bar")
    # #<ActiveRecord::Result:0x007ff34710a5f8>

    connection.select_all("SELECT a, b, c FROM bar").to_a
    # [{"a"=>"1", "b"=>"2"}, {"a"=>"4","b"=>"5"}]

- Or `ActiveRecord::Base.connection` outside models and migrations.
- Everything is a string.

Raw SQL 2
=========

    @@@ruby
    connection.select_values("SELECT a FROM bar")
    # ["1", "4"]

    connection.select_value("SELECT a FROM bar")
    # ["1"]

    connection.select_one("SELECT a FROM bar")
    # {"id"=>"1"}


Raw SQL quoting
===============

    @@@ruby
    connection.select_rows <<-EOQ
      SELECT  foo
      FROM    bar
      WHERE   baz = '#{connection.quote_string(raz)}'
    EOQ

- No `?` parameters like in `where`.
- Use `quote_string` to avoid SQLi.


Raw SQL to Models
=================

    @@@ruby
    def 
      User.find_by_sql <<-EOQ
        SELECT  *
        FROM    inspections
        WHERE   restaurant_id = #{id.to_i}
      EOQ
    end

- SQL Injection?!
  - `find_by_sql`, `execute`, `select_*`, `joins`: no `?` params
  - Always know from reading only the method body that it's safe.
  - `to_i` is safe



Simple `scope`
==============

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

All restaurants with no inspections yet:

    @@@sql
    SELECT  *
    FROM    restaurants r
    WHERE   NOT EXISTS (SELECT  1
                        FROM    inspections i
                        WHERE   i.restaurant_id = r.id)

- Less constraining than a join.



Subqueries with `scope`
=======================

    @@@ruby
    scope :without_inspection, where(<<-EOQ)
      NOT EXISTS (SELECT  1
                  FROM    inspections i
                  WHERE   i.restaurant_id = restaurants.id)
    EOQ



Merging scopes
==============

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

- Count the inspections in each month:

    @@@sql
    SELECT  EXTRACT('MONTH' FROM inspected_at) m,
            COUNT(*)
    FROM    inspections
    GROUP BY m
    ORDER BY m

- Excludes months with zero inspections!


Time Series with generate_series
================================

    @@@sql
    SELECT  s.m + 1 AS month,
            COUNT(id)
    FROM    generate_series(0, 11) s(m)
    LEFT OUTER JOIN inspections
    ON      inspected_at
            BETWEEN '2015-01-01'::date + (s.m || ' MONTHS')::interval
            AND     '2015-01-01'::date + ((s.m + 1) || ' MONTHS')::interval
    GROUP BY s.m
    ORDER BY s.m


generate_series in `from`
=========================

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
                BETWEEN '#{year.to_i}-01-01'::date + (s.m || ' MONTHS')::interval
                AND     '#{year.to_i}-01-01'::date + ((s.m + 1) || ' MONTHS')::interval
            AND inspections.restaurant_id = #{id.to_i}
          EOQ
          group("inspection_month").
          order("inspection_month")
      end
    end

- Later we can clean this up with a CTE.


    TODO: Same thing but with find_by_sql?



generate_series CTE
===================

    @@@sql
    WITH t(month) AS (
      SELECT  '2015-01-01'::date +
                (s.m || ' MONTHS')::interval
      FROM    generate_series(0, 11) s(m)
    )
    SELECT  t.month,
            COALESCE(sum(id), 0)
    FROM    t
    LEFT OUTER JOIN inspections
    ON      inspected_at BETWEEN month AND month + INTERVAL '1 MONTH'
    GROUP BY month
    ORDER BY month



generate_series in `with`
=========================

- Can't use `WITH` in ActiveRecord.
- Use the postgres_ext gem.

    @@@ruby
    class Restaurant
      def inspections_per_month
        Inspection.
          with("t(month)" => <<-EOQ).
            SELECT  '2015-01-01'::date +
                      (s.m || ' MONTHS')::interval
            FROM    generate_series(0, 11) s(m)
          EOQ
          select("t.month").
          select("COUNT(inspections.id) AS inspections_count").
          from("t").
          joins(<<-EOQ).
            LEFT OUTER JOIN inspections
            ON  inspections.inspected_at
                BETWEEN t.month AND t.month + INTERVAL '1 MONTH'
            AND inspections.restaurant_id = #{id.to_i}
          EOQ
          group("t.month").
          order("t.month")
      end
    end



Score of most recent inspection
===============================

- Get the list of restaurants.
- Include the score of the *just one* inspection.
- Avoid n+1 queries
- Include restaurants with no inspections yet.



Grouping and aggregates
=======================

Define a `FIRST` aggregate function:

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

    @@@ruby
    scope :with_latest_score, -> {
      select("restaurants.*").
        select(<<-EOQ).
          FIRST(inspections.score ORDER BY inspections.inspected_at DESC) AS latest_score
        EOQ
        joins(<<-EOQ).
          LEFT OUTER JOIN inspections
          ON inspections.restaurant_id = restaurants.id
        EOQ
        group("restaurants.id")
    }

- Any aggregate function permits `ORDER BY`.
- Forces a join and grouping: less composable.
- Grouping by `id` lets you select everything else.


More
====

- to_sql

- too many outer joins

- json and serializers

- using a CTE in rails

- using a window function in rails

- lateral joins

+ correlated sub-query

+ scopes

+ merge

- insert into returning

- pluck most recent score


Rails Migration Traps
=====================




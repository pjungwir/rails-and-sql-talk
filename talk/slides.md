Rails and SQL
=============

Paul A. Jungwirth

PDX.rb

May 2015



TODO
====


SQL overview
============

SELECT a FROM b WHERE c
SELECT a FROM b WHERE c GROUP BY d HAVING e


ActiveRecord overview
=====================

    @@@ruby
    @users = User.where(is_admin: true).
                  order(created_at: :desc)


ActiveRecord where
==================

    @@@ruby
    User.where(level: 5)
    User.where("level = ?", 5)


SQL inner vs outer join
=======================

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
  
produces either:

    @@@sql
    SELECT  *
    FROM    restaurants
    LEFT OUTER JOIN inspections
    ON      inspections.restaurant_id = restaurants.id
    WHERE   

    - also avoids the "n+1" problem

class User
  
end


Extra attributes with select
============================



- why use ActiveRecord at all?
  - scopes: composable query logic
  - instance methods
  - compat, e.g. will_paginate


Almost-Raw SQL
==============

    @@@ruby
    def 
      User.find_by_sql <<-EOQ
        SELECT  *
        FROM    inspections
        WHERE   restaurant_id = #{id.to_i}
      EOQ
    end

- SQL Injection?!
  - find_by_sql, execute, select_*, joins: no ? params
  - Always know from reading only the method body that it's safe.
  - to_i is safe

Raw SQL
=======

    TODO: check these

    @@@ruby
    connection.select_rows("SELECT a, b, c FROM bar")
    >>> [{a:1,b:2,c:3}, {d:4,d:5,d:6}]

    connection.select_values("SELECT a FROM bar")
    connection.select_value("SELECT a FROM bar")
    connection.select_one("SELECT a FROM bar")

- Or `ActiveRecord::Base.connection` outside models and migrations.

Raw SQL quoting
===============

TODO: sure it's quote_string?:

    @@@ruby
    ActiveRecord::Base.connection.select_rows <<-EOQ
      SELECT  foo
      FROM    bar
      WHERE   blorch = '#{ActiveRecord::Base.connection.quote_string(blech)}'
    EOQ

- No `?` parameters like in `where`.
- Use `quote_string` to avoid SQLi.

Time Series with generate_series
================================

    @@@sql
    SELECT  


- ActiveRecord from



More
====

- to_sql

- too many outer joins

- json and serializers

- using a CTE in rails

- using a window function in rails


Rails Migration Traps
=====================




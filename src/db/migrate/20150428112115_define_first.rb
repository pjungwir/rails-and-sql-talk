class DefineFirst < ActiveRecord::Migration
  # create some useful aggregate functions from here:
  # https://wiki.postgresql.org/wiki/First/last_%28aggregate%29
  
  def up
    connection.execute <<-EOQ
      CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
      RETURNS anyelement
      LANGUAGE sql IMMUTABLE STRICT
      AS $$
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

    connection.execute <<-EOQ
      CREATE OR REPLACE FUNCTION public.last_agg ( anyelement, anyelement )
      RETURNS anyelement
      LANGUAGE sql IMMUTABLE STRICT
      AS $$
      SELECT $1;
      $$;
    EOQ

    connection.execute <<-EOQ
      CREATE AGGREGATE public.last (
        sfunc    = public.last_agg,
        basetype = anyelement,
        stype    = anyelement
      );
    EOQ
  end

  def down
    connection.execute("DROP AGGREGATE public.last(anyelement)")
    connection.execute("DROP FUNCTION public.last_agg(anyelement, anyelement)")
    connection.execute("DROP AGGREGATE public.first(anyelement)")
    connection.execute("DROP FUNCTION public.first_agg(anyelement, anyelement)")
  end
end

class Restaurant < ActiveRecord::Base

  has_many :inspections, -> { order(:inspected_at) }
  has_many :violations, through: :inspections

  scope :without_inspection, -> {
    where(<<-EOQ)
      NOT EXISTS (SELECT  1
                  FROM    inspections i
                  WHERE   i.restaurant_id = restaurants.id)
    EOQ
  }


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



  # Use `select` to add computed attributes to your model.
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


  # Use `from` to change the base table.
  # Joining to the model's table still lets you get AR instances.
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

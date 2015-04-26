class Restaurant < ActiveRecord::Base

  has_many :inspections, -> { order(:inspected_at) }
  has_many :violations, through: :inspections

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
  def inspections_per_month
    Inspection.
      select("s.m AS inspection_month").
      # select("NOW() - (s.m || ' MONTHS')::interval AS inspection_month").
      select("COUNT(inspections.id) AS inspections_count").
      from("generate_series(1, 12) s(m)").
      joins(<<-EOQ).
        LEFT OUTER JOIN inspections
        ON  inspections.inspected_at
            BETWEEN NOW() - (s.m || ' MONTHS')::interval
            AND     NOW() - ((s.m - 1) || ' MONTHS')::interval
        AND inspections.restaurant_id = #{id.to_i}
      EOQ
      group("inspection_month").
      order("inspection_month")
  end


end

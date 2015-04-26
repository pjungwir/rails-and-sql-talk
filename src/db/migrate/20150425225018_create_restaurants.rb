class CreateRestaurants < ActiveRecord::Migration
  def change
    create_table :restaurants do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :inspections do |t|
      t.references :restaurant, null: false
      t.integer :score, null: false
      t.date :inspected_at, null: false
      t.timestamps null: false
    end
    add_foreign_key :inspections, :restaurants, options: "ON DELETE CASCADE"
    add_index :inspections, [:restaurant_id, :inspected_at]

    create_table :violations do |t|
      t.references :inspection, null: false
      t.string :name
      t.timestamps null: false
    end
    add_foreign_key :violations, :inspections, options: "ON DELETE CASCADE"
    add_index :violations, :inspection_id
  end
end

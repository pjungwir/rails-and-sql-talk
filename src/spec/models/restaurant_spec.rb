require 'spec_helper'

describe Restaurant do

  it 'saves when valid' do
    @restaurant = Restaurant.create!(name: "Bob's Diner")
  end



  context 'when summarizing' do

    before do
      @restaurant = Restaurant.create!(name: "Bob's Diner")
      @restaurant.inspections.create!(score: 100, inspected_at: Time.zone.now - 7.days)
      @restaurant.inspections.create!(score: 100, inspected_at: Time.zone.now - 14.days)
      @restaurant.inspections.create!(score: 100, inspected_at: Time.zone.now - 80.days)
    end



    it 'counts inspections per month' do
      @inspections = @restaurant.inspections_per_month
      @table = @inspections.map{|insp| [insp.inspection_month, insp.inspections_count]}

      # Months with zero inspections are included:
      expect(@table.take(4)).to eq([[1, 2], [2, 0], [3, 1], [4, 0]])
    end



    it 'counts violations per inspection' do
      @restaurant.inspections[0].violations.create!(name: "Rats")
      @restaurant.inspections[1].violations.create!(name: "Rats")
      @restaurant.inspections[1].violations.create!(name: "Zombies")

      @inspections = @restaurant.inspections_with_violation_counts.
                       reorder(inspected_at: :desc)   # composable b/c still an ActiveRecord::Relation

      expect(@inspections[0].violations_count).to eq 0
      expect(@inspections[1].violations_count).to eq 2
      expect(@inspections[2].violations_count).to eq 1
    end


  end

end

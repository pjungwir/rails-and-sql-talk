require 'spec_helper'

describe Restaurant do

  it 'saves when valid' do
    @restaurant = Restaurant.create!(name: "Bob's Diner")
  end


  context 'with inspections' do

    before do
      @bobs = Restaurant.create!(name: "Bob's Diner")
      @bobs.inspections.create!(score: 77, inspected_at: '2015-01-07')
      @bobs.inspections.create!(score: 71, inspected_at: '2015-01-15')
      @bobs.inspections.create!(score: 75, inspected_at: '2015-03-15')
      @joes = Restaurant.create!(name: "Joe's Place")
    end


    it 'finds places with no inspections' do
      @uninspected = Restaurant.without_inspection
      expect(@uninspected.count).to eq 1
      expect(@uninspected.first).to eq @joes
    end



    it 'counts inspections per month' do
      @inspections = @bobs.inspections_per_month(2015)
      @table = @inspections.map{|insp| [insp.inspection_month, insp.inspections_count]}

      # Months with zero inspections are included:
      expect(@table.take(4)).to eq([[1, 2], [2, 0], [3, 1], [4, 0]])
    end



    it 'counts violations per inspection' do
      @bobs.inspections[0].violations.create!(name: "Rats")
      @bobs.inspections[1].violations.create!(name: "Rats")
      @bobs.inspections[1].violations.create!(name: "Zombies")

      @inspections = @bobs.inspections_with_violation_counts.
                       reorder(inspected_at: :desc)   # composable b/c still an ActiveRecord::Relation

      expect(@inspections[0].violations_count).to eq 0
      expect(@inspections[1].violations_count).to eq 2
      expect(@inspections[2].violations_count).to eq 1
    end



    it 'includes most recent score' do
      @table = Restaurant.with_latest_score.order(:name)
      expect(@table[0].name).to eq("Bob's Diner")
      expect(@table[0].latest_score).to eq 75
      expect(@table[1].name).to eq("Joe's Place")
      expect(@table[1].latest_score).to eq nil
    end



    it 'includes most recent score via lateral join' do
      @table = Restaurant.with_latest_score_lateral_join.order("latest.score DESC NULLS LAST")
      expect(@table[0].name).to eq("Bob's Diner")
      expect(@table[0].latest_score).to eq 75
      expect(@table[1].name).to eq("Joe's Place")
      expect(@table[1].latest_score).to eq nil
    end



    it 'finds places with a perfect score' do
      @crystal = Restaurant.create!(name: "Crystal Palace")
      @crystal.inspections.create!(score: 100, inspected_at: '2015-01-07')
      @clean = Restaurant.with_a_perfect_score
      expect(@clean.size).to eq 1
      expect(@clean.first).to eq @crystal
    end


  end

end

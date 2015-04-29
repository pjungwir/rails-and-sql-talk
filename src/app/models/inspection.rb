class Inspection < ActiveRecord::Base

  belongs_to :restaurant
  has_many :violations

  scope :perfect, -> { where(score: 100) }

end

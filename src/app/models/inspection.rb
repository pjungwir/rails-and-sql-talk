class Inspection < ActiveRecord::Base

  belongs_to :restaurant
  has_many :violations

end

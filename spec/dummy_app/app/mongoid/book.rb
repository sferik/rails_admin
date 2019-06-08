class Book
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title, type: String
  has_and_belongs_to_many :authors, inverse_of: nil, primary_key: 'name', foreign_key: "people"

  validates_presence_of(:title)
end

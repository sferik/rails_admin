class Book < ActiveRecord::Base
  has_and_belongs_to_many :authors, foreign_key: 'custom_book_id', association_foreign_key: 'custom_author_id'

  validates_presence_of(:title)
end

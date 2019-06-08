class Author < ActiveRecord::Base
  has_and_belongs_to_many :books, foreign_key: 'custom_author_id', association_foreign_key: 'custom_book_id'

  validates_presence_of(:name)
end

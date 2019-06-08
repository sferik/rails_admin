class CreateJoinTableBookAuthor < MigrationBase
  def change
    create_join_table :books, :authors do |t|
      # t.index [:book_id, :author_id]
      # t.index [:author_id, :book_id]
    end
  end
end

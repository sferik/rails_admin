class RenameColumes < MigrationBase
  def change
    rename_column :authors_books, :book_id, :custom_book_id
    rename_column :authors_books, :author_id, :custom_author_id
  end
end

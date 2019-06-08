class CreateAuthors < MigrationBase
  def change
    create_table :authors do |t|
      t.string :name

      t.timestamps
    end
  end
end

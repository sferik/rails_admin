class CreateBooks < MigrationBase
  def change
    create_table :books do |t|
      t.string :title

      t.timestamps
    end
  end
end

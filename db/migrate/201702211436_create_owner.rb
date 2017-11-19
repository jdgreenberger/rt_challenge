class CreateOwner < ActiveRecord::Migration
  def up
    create_table :owners do |t|
      t.integer :poid
      t.string  :name
      t.string  :initials
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def down
    drop_table :owners
  end
end

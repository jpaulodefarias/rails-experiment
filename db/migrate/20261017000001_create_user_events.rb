class CreateUserEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :user_events do |table|
      table.string :event_id, null: false
      table.bigint :user_id, null: false
      table.string :action, null: false
      table.jsonb :payload, null: false
      table.datetime :published_at
      table.timestamps
    end

    add_index :user_events, :event_id, unique: true
    add_index :user_events, %i[published_at id]
  end
end

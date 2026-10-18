class AddRetryStateToUserEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :user_events, :attempts, :integer, null: false, default: 0
    add_column :user_events, :next_attempt_at, :datetime
    add_column :user_events, :last_error_class, :string

    add_index :user_events, %i[user_id id],
              where: "published_at IS NULL",
              name: "index_pending_user_events_on_user_id_and_id"
  end
end

class CreateDailyExtracts < ActiveRecord::Migration
  def change
    create_table :daily_extracts do |t|

      t.timestamps
    end
  end
end

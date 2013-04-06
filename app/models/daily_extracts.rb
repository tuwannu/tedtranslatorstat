class DailyExtracts < ActiveRecord::Base
  # attr_accessible :title, :body
  attr_accessor :firstScrapeDate
  attr_accessible :firstScrapeDate

  attr_accessor :lastActiveDate
  attr_accessible :lastActiveDate
end

class TranslationsController < ApplicationController
	respond_to :json, :html

	def index
		
	end

	def language
		@totalTranslators = DailyExtracts.select("count(ted_id) as translators").where("for_language = ?", params[:language]).group("for_date").order("for_date ASC").last
		@totalTasksCompleted = DailyExtracts.select("sum(translations) as tasks").where("for_language = ?", params[:language]).group("for_date").order("for_date ASC").last
		@translators = DailyExtracts.select("ted_id, profile_url, name, translations, location").where("for_language = ?", params[:language]).where(:for_date => DailyExtracts.select("MAX(for_date)")).order("translations DESC")

		@newTranslators = 0

		@translators.each do |translator|

			translator.firstScrapeDate = DailyExtracts.select("for_date").where("for_language = ?", params[:language]).where(:ted_id => translator.ted_id).order("for_date ASC").first.for_date

			if (Date.today - translator.firstScrapeDate).to_i < 14 then
				@newTranslators += 1
			end
		end

		@newCompletedTasks = DailyExtracts.select("SUM(translations) as translations").where("for_language = ?", params[:language]).group("for_date").order('for_date ASC').last.translations - DailyExtracts.select("translations").where("for_language = ?", params[:language]).where("for_date = ?", Date.today - Date.today.wday - 7).sum("translations")
	end

	def total

		if params[:duration] != nil
			records = DailyExtracts.select("for_language, for_date, sum(translations) as translations").where("for_language = ?", params[:language]).where(:for_date => (Time.now.months_ago(params[:duration].to_i).to_date..Time.now.to_date)).group("for_date")
		else
			records = DailyExtracts.select("for_language, for_date, sum(translations) as translations").where("for_language = ?", params[:language]).group("for_date")
		end

		respond_with records

	end

end
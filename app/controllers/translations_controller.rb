class TranslationsController < ApplicationController
	respond_to :html, :only => [:index, :language, :translator]
	respond_to :json, :only => [:total, :translator_history]

	def index
		
	end

	def language
		@totalTranslators = DailyExtracts.select("count(ted_id) as translators").where("for_language = ?", params[:language]).group("for_date").order("for_date ASC").last
		@totalTasksCompleted = DailyExtracts.select("sum(translations) as tasks").where("for_language = ?", params[:language]).group("for_date").order("for_date ASC").last
		@translators = DailyExtracts.select("ted_id, profile_url, name, translations, location").where("for_language = ?", params[:language]).where(:for_date => DailyExtracts.select("MAX(for_date)")).order("translations DESC")

		@newTranslators = 0
		@activeTranslators = 0

		@translators.each do |translator|

			translator.firstScrapeDate = DailyExtracts.select("for_date").where("for_language = ?", params[:language]).where(:ted_id => translator.ted_id).order("for_date ASC").limit(1).first.for_date

			if (Date.today - translator.firstScrapeDate).to_i < 14 then
				@newTranslators += 1
			end

			previousForDate = DailyExtracts.select("for_date").where("for_language = ?", params[:language]).where(:ted_id => translator.ted_id).where("translations != ?", translator.translations).order("for_date DESC").limit(1).first
			
			if previousForDate then

				translator.lastActiveDate = previousForDate.for_date

				if (Date.today - translator.lastActiveDate).to_i < 14 then
					@activeTranslators += 1
				end

			else
				translator.lastActiveDate = translator.firstScrapeDate
			end

		end

		@newCompletedTasks = DailyExtracts.select("SUM(translations) as translations").where("for_language = ?", params[:language]).group("for_date").order('for_date DESC').limit(1).first.translations - DailyExtracts.select("translations").where("for_language = ?", params[:language]).where("for_date = ?", Date.today - 14).sum("translations")
	end

	def total

		if params[:duration] != nil
			records = DailyExtracts.select("for_language, for_date, sum(translations) as translations").where("for_language = ?", params[:language]).where(:for_date => (Time.now.months_ago(params[:duration].to_i).to_date..Time.now.to_date)).group("for_date")
		else
			records = DailyExtracts.select("for_language, for_date, sum(translations) as translations").where("for_language = ?", params[:language]).group("for_date")
		end

		respond_with records

	end

	def translator_history
		respond_with DailyExtracts.select("ted_id, profile_url, name, photo_url, location, profile_languages, for_language, translations, for_date").where(:ted_id => params[:ted_id]).where(:for_language => params[:language]).order("for_date ASC")
	end

	def translator
		@translatorProfile = DailyExtracts.select("ted_id, profile_url, name, photo_url, location, profile_languages, for_language, translations, for_date").where(:ted_id => params[:ted_id]).where(:for_language => params[:language]).order("for_date DESC").limit(1).first
		@firstScrapeDate = DailyExtracts.select("for_date").where("for_language = ?", params[:language]).where(:ted_id => params[:ted_id]).order("for_date ASC").first.for_date
		@totalCompletedTasksInLanguage = DailyExtracts.select("SUM(translations) as translations").where("for_language = ?", params[:language]).group("for_date").order('for_date DESC').limit(1).first.translations

		previousForDate = DailyExtracts.select("for_date").where("for_language = ?", params[:language]).where(:ted_id => params[:ted_id]).where("translations != ?", @translatorProfile.translations).order("for_date DESC").limit(1).first
		if previousForDate then
			@lastActiveDate = previousForDate.for_date
		else
			@lastActiveDate = @firstScrapeDate
		end
	end

end
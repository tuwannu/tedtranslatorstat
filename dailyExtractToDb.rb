require 'open-uri'
require 'nokogiri'
require 'mysql2'

startTime = Time.new.getlocal("+07:00")

scrape_languages = ['th', 'sv', 'nl']

# languages = []

log_text = "Script start executing at #{startTime}\n"

class Translator
	attr_reader :ted_id
	attr_reader :name
	attr_reader :profile_url
	attr_reader :photo_url
	attr_reader :location
	attr_reader :profile_languages
	attr_reader :for_language
	attr_reader :translations

	def initialize(ted_id, name, profile_url, photo_url, location, profile_languages, for_language, translations)
		@ted_id = ted_id
		@name = name
		@profile_url = profile_url
		@photo_url = photo_url
		@location = location
		@profile_languages = profile_languages
		@for_language = for_language
		@translations = translations
	end
end

scrape_languages.each do |scrape_language|
	log_text << "#{Time.new.getlocal("+07:00")}: Start scraping for language: #{scrape_language}\n"

	page = 1
	more_page = true
	scraping_success = true
	translators = []

	while (more_page == true && scraping_success != false)
		url = "http://www.ted.com/translate/translators/lang/#{scrape_language}/page/#{page}"

		begin
			log_text << "#{Time.new.getlocal("+07:00")}: Fetching: #{url}\n"
			rawhtml = open(URI.encode(url))
		rescue
			log_text << "#{Time.new.getlocal("+07:00")}: Error while retrieving from #{url}\n"
			scraping_success = false
			break
		end

		doc = Nokogiri::HTML.parse(rawhtml)

		# Extract languages for the first page
		# if page == 1
		# 	doc.css('div.actions select > option').each do |langs|
		# 	  languages << langs.text.strip
		# 	end
		# end
		
		# Extract translators in the page
		begin
			doc.css('div.medallions ul > li').each do |medallion|

				profile_url = medallion.css('a').first['href']
				ted_id = profile_url.gsub("/profiles/", "")
				name = medallion.css('p.name').text
				photo_url = medallion.css('img').first['src']
				location = medallion.css('p.location').text.strip

				medallion.css('p:nth-of-type(3) em').remove()
				profile_languages = medallion.css('p:nth-of-type(3)').text.strip
				for_language = scrape_language

				translations = medallion.css('p:nth-of-type(4) span').text.strip

				translators << Translator.new(ted_id, name, profile_url, photo_url, location, profile_languages, for_language, translations)
			end

			# Extract last page number if exists
			# If this is already last page, then stops fetching
			last_page = doc.css('div.pagination ul li.last').text.strip.to_i
			if last_page == page
				more_page = false
			else
				page += 1
			end
		rescue
			log_text << "#{Time.new.getlocal("+07:00")}: Error while parsing from #{url}\n"
			scraping_success = false
			break
		end

	end

	if scraping_success == true

		log_text << "#{Time.new.getlocal("+07:00")}: #{translators.count} scraped.\n"

		client = Mysql2::Client.new(
			:host => ENV['OPENSHIFT_MYSQL_DB_HOST'], 
			:username => ENV['OPENSHIFT_MYSQL_DB_USERNAME'], 
			:password => ENV['OPENSHIFT_MYSQL_DB_PASSWORD'],
			:database => "tedtranslatorstat"
			)

		insert_success_count = 0

		translators.each do |t|
			client.query("
				INSERT INTO daily_extracts (
					`ted_id`, 
					`profile_url`, 
					`name`, 
					`photo_url`, 
					`location`, 
					`profile_languages`, 
					`for_language`,
					`translations`, 
					`for_date`, 
					`date_extracted`
				) VALUES (
					'#{t.ted_id}', 
					'#{t.profile_url}', 
					'#{t.name}', 
					'#{t.photo_url}', 
					'#{t.location}', 
					'#{t.profile_languages}',
					'#{t.for_language}',
					'#{t.translations}', 
					NOW(), 
					NOW()
				);
			")
			insert_success_count += 1
		end

		client.close()

		log_text << "#{Time.new.getlocal("+07:00")}: #{insert_success_count} records inserted.\n"
		log_text << "----------------------------------\n\n"
	end

	# Rest for 15 seconds before scraping the next language
	sleep 15

end

log_text << "#{Time.new.getlocal("+07:00")}: Daily extract completed in #{Time.new.getlocal("+07:00")-startTime} seconds.\n"

begin
	File.open(ENV['OPENSHIFT_DATA_DIR'] + "custom_log/dailyExtractToDb.rb.log", 'a') {|f| f.write(log_text) }
rescue
	puts "Error logging to file."
end
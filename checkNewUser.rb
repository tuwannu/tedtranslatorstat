require 'open-uri'
require 'nokogiri'

startTime = Time.new.getlocal("+07:00")

log_text = "Script start executing at #{startTime}\n"

LastTranslator.all.each do |lastTranslator|

	language = lastTranslator.language
	languageCode = lastTranslator.code
	lcEmails = lastTranslator.lc_emails

	if lastTranslator.disabled?
		log_text << "#{Time.new.getlocal("+07:00")}: Skipping language: #{language}\n"
		next
	end

	log_text << "#{Time.new.getlocal("+07:00")}: Start scraping for language: #{language}\n"

	if !lastTranslator then
		log_text << "#{Time.new.getlocal("+07:00")}: Record for #{language} not found. Skipping this language.\n"
		next
	end

	log_text << "#{Time.new.getlocal("+07:00")}: Latest translator for #{language} was: #{lastTranslator.amara_id} on page #{lastTranslator.last_page}.\n"

	page = lastTranslator.last_page
	lastPage = false
	newTranslators = []

	until lastPage do
		url = "http://www.amara.org/en-gb/teams/ted/members/?lang=#{languageCode}&page=#{page}"

		begin
			log_text << "#{Time.new.getlocal("+07:00")}: Fetching: #{url}\n"
			rawhtml = open(URI.encode(url))
		rescue => errorDetails
			log_text << "#{Time.new.getlocal("+07:00")}: Error while retrieving from #{url}\n"
			log_text << "#{Time.new.getlocal("+07:00")}: Error message: #{errorDetails.message}\n"
			lastPage = true
			next
		end

		doc = Nokogiri::HTML.parse(rawhtml)

		if doc.css('div.pagination span.next_page').size > 0 && doc.css('div.pagination span.next_page.disabled').size == 0 then
			page += 1
		else
			lastPage = true
		end

		translatorsInPage = []

		doc.css('ul.members.listing > li').each do |translator|
			translatorsInPage << translator.css('h3 > a').first['href'].split('/')[-1, 1][0]
		end

		lastTranslatorIndex = translatorsInPage.index(lastTranslator.amara_id)

		if lastTranslatorIndex then
			translatorsInPage.shift(lastTranslatorIndex + 1)
		end

		newTranslators |= translatorsInPage

	end

	log_text << "#{Time.new.getlocal("+07:00")}: Found #{newTranslators.length} new #{language} translators\n"

	if newTranslators.length > 0 then
		log_text << "#{Time.new.getlocal("+07:00")}: Sending email to #{language} LCs (#{lcEmails}).\n"
		
		begin
			LanguageCoMailer.new_translators_email(languageCode, language, lcEmails, newTranslators).deliver
		rescue => errorDetails
			log_text << "#{Time.new.getlocal("+07:00")}: Error sending email with message: \"#{errorDetails.message}\". Skipping this language. \n"
			next
		end

		t = newTranslators[-1, 1][0]
		lastTranslator.amara_id = t
		lastTranslator.date_found = Time.now
		lastTranslator.last_page = page

		lastTranslator.save

		log_text << "#{Time.new.getlocal("+07:00")}: Latest translator for #{language} is now: #{lastTranslator.amara_id} on page #{lastTranslator.last_page}\n"
	end

	log_text << "#{Time.new.getlocal("+07:00")}: -----------------------------------\n"

	sleep 2

end

log_text << "#{Time.new.getlocal("+07:00")}: Check new user completed in #{Time.new.getlocal("+07:00")-startTime} seconds.\n"

begin
	if Rails.env.production?
		File.open("#{ENV['OPENSHIFT_DATA_DIR']}custom_log/checkNewUser.rb.log", 'a') {|f| f.write(log_text) }
	else
		File.open("./custom_log/checkNewUser.rb.log", 'a') {|f| f.write(log_text) }
	end	
rescue => errorDetails
	puts "Error logging to file with the following message:\n"
	puts "#{errorDetails.message}\n"
	puts "Error Backtrace:\n"
	puts errorDetails.backtrace.join("\n") + '\n'
	puts "Trying to log: \n" + log_text
end

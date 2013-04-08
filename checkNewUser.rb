require 'open-uri'
require 'nokogiri'

startTime = Time.new.getlocal("+07:00")

language_coordinators = [
	{ :language => 'Thai', :code => 'th', :emails => 'removed@removed.com' },
	{ :language => 'Polish', :code => 'pl', :emails => 'removed@removed.com' },
	{ :language => 'French', :code => 'fr', :emails => 'removed@removed.com' },
	{ :language => 'Urdu', :code => 'ur', :emails => 'removed@removed.com' },
	{ :language => 'Dutch', :code => 'nl', :emails => 'removed@removed.com' },
	{ :language => 'Russian', :code => 'ru', :emails => 'removed@removed.com' },
	{ :language => 'Latvian', :code => 'lv', :emails => 'removed@removed.com' },
	{ :language => 'Japanese', :code => 'ja', :emails => 'removed@removed.com' },
#	{ :language => '', :code => '', :emails => '' },
]

log_text = "Script start executing at #{startTime}\n"

language_coordinators.each do |lc|
	log_text << "#{Time.new.getlocal("+07:00")}: Start scraping for language: #{lc[:language]}\n"

	lastTranslator = LastTranslator.find_by_for_language(lc[:code])

	if !lastTranslator then
		log_text << "#{Time.new.getlocal("+07:00")}: Record for #{lc[:language]} not found. Skipping this language.\n"
		next
	end

	log_text << "#{Time.new.getlocal("+07:00")}: Last page was: #{lastTranslator.last_page}. Latest Amara ID was: #{lastTranslator.amara_id}.\n"

	page = lastTranslator.last_page.to_i
	lastPage = false
	newTranslators = []

	until lastPage do
		url = "http://www.amara.org/en-gb/teams/ted/members/?lang=#{lc[:code]}&page=#{page}"

		begin
			log_text << "#{Time.new.getlocal("+07:00")}: Fetching: #{url}\n"
			rawhtml = open(URI.encode(url))

			# rawhtml = File.open("amaratest.html")

			log_text << "#{Time.new.getlocal("+07:00")}: Fetching completed.\n"
		rescue
			log_text << "#{Time.new.getlocal("+07:00")}: Error while retrieving from #{url}\n"
			lastPage = true
			next
		end

		doc = Nokogiri::HTML.parse(rawhtml)
		# rawhtml.close

		if doc.css('div.pagination span.next_page.disabled').size > 0 then
			lastPage = true
		else
			page += 1
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

	log_text << "#{Time.new.getlocal("+07:00")}: Found #{newTranslators.length} new #{lc[:language]} translators\n"

	if newTranslators.length > 0 then
		log_text << "Sending email to #{lc[:emails]} for language #{lc[:language]}.\n"
		LanguageCoMailer.new_translators_email(lc[:code], lc[:language], lc[:emails], newTranslators).deliver

		t = newTranslators[-1, 1][0]
		lastTranslator.amara_id = t
		lastTranslator.date_found = Time.now
		lastTranslator.last_page = page

		lastTranslator.save

		log_text << "#{Time.new.getlocal("+07:00")}: Last translator for #{lc[:language]} is now: #{lastTranslator.amara_id} on page #{lastTranslator.last_page}\n"
	end

	sleep 2

end

log_text << "#{Time.new.getlocal("+07:00")}: Check new user completed in #{Time.new.getlocal("+07:00")-startTime} seconds.\n"

begin
	File.open(ENV['OPENSHIFT_REPO_DIR'] + "custom_log/checkNewUser.rb.log", 'a') {|f| f.write(log_text) }	
	# puts log_text
rescue
	puts "Error logging to file."
end

require 'open-uri'
require 'nokogiri'
require 'mysql2'

startTime = Time.new

languages = []
translators = []

page = 1
more_page = true

class Translator
	attr_reader :ted_id
	attr_reader :name
	attr_reader :profile_url
	attr_reader :photo_url
	attr_reader :location
	attr_reader :languages
	attr_reader :translations

	def initialize(ted_id, name, profile_url, photo_url, location, languages, translations)
		@ted_id = ted_id
		@name = name
		@profile_url = profile_url
		@photo_url = photo_url
		@location = location
		@languages = languages
		@translations = translations
	end
end

while more_page == true
	url = "http://www.ted.com/translate/translators/lang/th/page/#{page}"

	begin
		puts "Fetching: #{url}"
		rawhtml = open(URI.encode(url))
	rescue
		puts "Error while retrieving from #{url}"
		break
	end

	doc = Nokogiri::HTML.parse(rawhtml)

	# Extract languages for the first page
	if page == 1
		doc.css('div.actions select > option').each do |langs|
		  languages << langs.text.strip
		end
	end
	
	# Extract translators in the page
	doc.css('div.medallions ul > li').each do |medallion|

		profile_url = medallion.css('a').first['href']
		ted_id = profile_url.gsub("/profiles/", "")
		name = medallion.css('p.name').text
		photo_url = medallion.css('img').first['src']
		location = medallion.css('p.location').text.strip

		medallion.css('p:nth-of-type(3) em').remove()
		languages = medallion.css('p:nth-of-type(3)').text.strip

		translations = medallion.css('p:nth-of-type(4) span').text.strip

		translators << Translator.new(ted_id, name, profile_url, photo_url, location, languages, translations)
	end

	# Extract last page number if exists
	# If this is already last page, then stops fetching
	last_page = doc.css('div.pagination ul li.last').text.strip.to_i
	if last_page == page
		more_page = false
	else
		page += 1
	end

end

client = Mysql2::Client.new(
	:host => ENV['OPENSHIFT_MYSQL_DB_HOST'], 
	:username => ENV['OPENSHIFT_MYSQL_DB_USERNAME'], 
	:password => ENV['OPENSHIFT_MYSQL_DB_PASSWORD'],
	:database => "tedtranslatorstat"
	)

translators.each do |t|
	client.query("
		INSERT INTO dailyextracts (
			`ted_id`, 
			`profile_url`, 
			`name`, 
			`photo_url`, 
			`location`, 
			`languages`, 
			`translations`, 
			`for_date`, 
			`date_extracted`
		) VALUES (
			'" + t.ted_id + "', 
			'" + t.profile_url + "', 
			'" + t.name + "', 
			'" + t.photo_url + "', 
			'" + t.location + "', 
			'" + t.languages + "', 
			'" + t.translations + "', 
			NOW(), 
			NOW()
		);
	")
end

client.close()

puts "#{Time.new}: " + translators.count + " records inserted."

puts "#{Time.new}: Daily extract completed in #{Time.new-startTime} seconds."
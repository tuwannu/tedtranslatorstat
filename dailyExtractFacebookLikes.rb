require 'open-uri'
require 'nokogiri'
require 'mysql2'
require 'rubygems'
require 'json'

startTime = Time.new.getlocal("+07:00")

$log_text = ""

fetch_languages = ['th']

def post_log(message)
	message = "#{Time.new.getlocal("+07:00")}: #{message}"
	puts message
	$log_text << message + "\n"
end

post_log "Script start executing"

class ScrapedTalk
	attr_reader :title
	attr_reader :url
	attr_reader :date_published

	def initialize(title, url, date_published)
		@title = title
		@url = url
		@date_published = date_published
	end
end

class Talk
	attr_reader :title
	attr_reader :language
	attr_reader :url
	attr_reader :date_published
	attr_reader :like_count
	attr_reader :comment_count
	attr_reader :share_count
	attr_reader :total_count

	def initialize(title, language, url, date_published, like_count, comment_count, share_count, total_count)
		@title = title
		@language = language
		@url = url
		@date_published = date_published
		@like_count = like_count
		@comment_count = comment_count
		@share_count = share_count
		@total_count = total_count
	end
end

post_log "Start scraping list of all talks."

page = 1
more_page = true
scraping_success = true
scrapedTalks = []
talks = []

while (more_page == true && scraping_success != false)
	url = "http://www.ted.com/talks/quick-list?sort=date&order=desc&page=#{page}"

	begin
		post_log "Fetching: #{url}"
		rawhtml = open(URI.encode(url))
	rescue
		post_log "Error while retrieving from #{url}"
		scraping_success = false
		break
	end

	doc = Nokogiri::HTML.parse(rawhtml)
	
	# Convert parsed JSON into objects for internal use
	begin

		# Starting from (n + 2) child becase first <tr> is the table header
		doc.css('table.downloads > tr:nth-child(n + 2)').each do |row|

			title = row.css('td:nth-child(3) a').text.strip
			url = row.css('td:nth-child(3) a')[0]['href']
			date_published = row.css('td:nth-child(1)').text.strip

			scrapedTalks << ScrapedTalk.new(title, url, date_published)

		end

	rescue => errorDetails
		post_log "Error while parsing from #{url}."
		post_log "Error message: #{errorDetails.message}"
		scraping_success = false
		break
	end

	# Extract last page number if exists
	# If this is already last page, then stops fetching
	last_page = doc.css('div.pagination ul li.last').text.strip.to_i

	if last_page == page
		more_page = false
		post_log "Total of #{scrapedTalks.count} scraped."
	else
		page += 1
		post_log "#{scrapedTalks.count} talks scraped."
	end

end

# If scraping all talks from TED.com is successful, 
# continue with fetching Facebook data for each talk for each language.
if scraping_success == true

	# Loop for each language
	fetch_languages.each do |fetch_language|

		post_log "Fetching Facebook info for language: #{fetch_language}"

		# Loop for each talk
		scrapedTalks.each do |scrapedTalk|

			title = scrapedTalk.title

			url = scrapedTalk.url
			url["/talks"] = "/talks/lang/#{fetch_language}"

			date_published = scrapedTalk.date_published

			begin

				facebook_info = JSON.parse(open(URI.encode("https://api.facebook.com/method/fql.query?query=select total_count,like_count,comment_count,share_count,click_count from link_stat where url='http://www.ted.com#{url}'&format=json")).read)

				like_count = facebook_info[0]["like_count"]
				comment_count = facebook_info[0]["comment_count"]
				share_count = facebook_info[0]["share_count"]
				total_count = facebook_info[0]["total_count"]

				talks << Talk.new(title, fetch_language, url, date_published, like_count, comment_count, share_count, total_count)

				if talks.count % 10 == 0
					post_log "#{talks.count} Facebook records fetched."
					sleep 1
				end

			rescue => errorDetails
				# Escaping in case Facebook returns unexpected response
				post_log "Error occurred while fetching Facebook data for url: #{url}."
				post_log "Error message: #{errorDetails.message}"
			end

		end

	end

end

if talks.count > 0
	post_log "#{talks.count} stats records will be added to database."

	client = Mysql2::Client.new(
		:host => ENV['OPENSHIFT_MYSQL_DB_HOST'], 
		:username => ENV['OPENSHIFT_MYSQL_DB_USERNAME'], 
		:password => ENV['OPENSHIFT_MYSQL_DB_PASSWORD'],
		:database => "tedtranslatorstat"
		)

	insert_success_count = 0

	talks.each do |t|

		client.query("
			INSERT INTO facebook_stats (
				`title`, 
				`language`, 
				`url`, 
				`date_published`, 
				`like_count`, 
				`comment_count`,
				`share_count`,
				`total_count`, 
				`for_date` 
			) VALUES (
				'#{t.title.gsub("'", "\\\\'")}', 
				'#{t.language}', 
				'#{t.url}', 
				'#{t.date_published}', 
				'#{t.like_count}', 
				'#{t.comment_count}',
				'#{t.share_count}',
				'#{t.total_count}',
				NOW()
			);
		")

		insert_success_count += 1

	end

	client.close()

	post_log "#{insert_success_count} records inserted to DB."
	post_log "----------------------------------\n"
end

post_log "Daily extract completed in #{Time.new.getlocal("+07:00")-startTime} seconds."

begin
	File.open(ENV['OPENSHIFT_REPO_DIR'] + "custom_log/dailyExtractFacebookLikes.rb.log", 'a') {|f| f.write($log_text) }
rescue
	puts "Error logging to file.\n"
	puts "---------- Dumping log_text ----------\n"
	puts $log_text
	puts "---------- End of log_text dump ----------\n"
end
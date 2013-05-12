require 'open-uri'
require 'nokogiri'
require 'mysql2'
require 'rubygems'
require 'json'

startTime = Time.new.getlocal("+07:00")

$log_text = ""

fetch_languages = ['th', 'de']
slice_size = 15

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
		# Sleep for 2 seconds before fetching next page
		sleep 1
	end

end

# If scraping all talks from TED.com is successful, 
# continue with fetching Facebook data for each talk for each language.
if scraping_success == true

	# Loop for each language
	fetch_languages.each do |fetch_language|

		post_log "Fetching Facebook info for language: #{fetch_language}"

		# Slice into chunks, then loop for each chunks
		scrapedTalks.each_slice(slice_size) do |scrapedTalksChunk|
			fql_url = ""

			# Prepare url for each chunk
			scrapedTalksChunk.each do |scrapedTalk|

				tedUrl = scrapedTalk.url.gsub("/talks", "/talks/lang/#{fetch_language}")

				# if url is empty, prepare the beginning part of the FQL url
				if tedUrl != "" && fql_url == ""
					fql_url = "https://api.facebook.com/method/fql.query?query="
					fql_url << "select url,total_count,like_count,comment_count,share_count,click_count from link_stat "
					fql_url << "where url='http://www.ted.com#{tedUrl}'"
				elsif tedUrl != "" && fql_url != ""
					# if url is not empty, then just append an or clause to the url
					fql_url << " or url='http://www.ted.com#{tedUrl}'"
				end # end of preparing FQL url for one chunk

			end # end of looping through all chunks

			fql_url << "&format=json"

			# Fetch Facebook info for the given talks batch
			begin
				facebook_info = nil
				facebook_info = JSON.parse(open(URI.encode(fql_url)).read)
			rescue => errorDetails
				# Escaping in case Facebook returns unexpected response
				post_log "Error occurred while fetching Facebook data for url: #{fql_url}."
				post_log "Error message: #{errorDetails.message}"
			end #end fetching from Facebook FQL

			# Check that result if returned from FQL,
			# if so, process the FQL result
			if facebook_info != nil

				# Loop for each returned FQL record
				facebook_info.each do |fb|

					# Facebook FQL returns full URL, 
					# trim the top domain so we can match with data we got from TED.com
					url = fb["url"].gsub('http://www.ted.com', '')

					# Match between Facebook FQL record and TED.com record
					scraped_talk_index = scrapedTalksChunk.index { |talk| talk.url.gsub("/talks", "/talks/lang/#{fetch_language}") == url }

					# if found matching url between FQL and TED.com,
					# then gather information from FQL and TED.com into one piece,
					# and put for storage
					if scraped_talk_index != nil

						# prepare Facebook result for storage
						like_count = fb["like_count"]
						comment_count = fb["comment_count"]
						share_count = fb["share_count"]
						total_count = fb["total_count"]

						# prepare TED.com record for storage
						title = scrapedTalksChunk[scraped_talk_index].title
						date_published = scrapedTalksChunk[scraped_talk_index].date_published

						talks << Talk.new(title, fetch_language, url, date_published, like_count, comment_count, share_count, total_count)
					
					end #end of merging and storing records from FQL and TED.com

				end # end looping for each returned FQL record

				post_log "#{talks.count} records fetched and merged."
			end # end of processing FQL result

			# If fetched FQL for 5 times, sleep for 2 seconds to give Facebook a break
			if talks.count % (slice_size * 5) == 0
				sleep 1
			end

		end #end of looping chunks

	end #end loop for each language

end #end condition if scraping from TED.com is successful

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
end

post_log "Daily extract completed in #{Time.new.getlocal("+07:00")-startTime} seconds."
post_log "----------------------------------\n"

begin
	File.open(ENV['OPENSHIFT_DATA_DIR'] + "custom_log/dailyExtractFacebookLikes.rb.log", 'a') {|f| f.write($log_text) }
rescue
	puts "Error logging to file.\n"
	puts "---------- Dumping log_text ----------\n"
	puts $log_text
	puts "---------- End of log_text dump ----------\n"
end
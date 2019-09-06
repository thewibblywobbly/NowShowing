#!/usr/bin/ruby
require 'yaml'
require 'rubygems'
require 'json'
require 'httparty'

# Class To interact with Tautulli, for pulling statistics
# Author: Ninthwalker
# Full api path: http://ip:port + HTTP_ROOT + /api/v2?apikey=$apikey&cmd=$command

# key:
# m => pop movie
# v => pop tv
# a = > pop artist
# d => day movie
# D => day TV
# t => movie time
# T => TV time
# u => top user
# s => stream count
# c => Recently added counts
# A => totals (movie and tv)
# S => include songs in total

class Tautulli
    include HTTParty
    format :json
	
    def initialize
        $advanced = YAML.load_file('/config/cfg/advanced.yaml')
		$time  = $advanced['report']['interval']
        $server = $advanced['tautulli']['server']
		$port = $advanced['tautulli']['port']
		$api_key = $advanced['tautulli']['api_key']
		$httproot = "/" + $advanced['tautulli']['httproot']
		$https = $advanced['tautulli']['https']
		$stats = $advanced['tautulli']['stats']

	if !$server.nil?
            if $https == 'no'
                self.class.base_uri "http://#{$server}:#{$port}#{$httproot}/api/v2?apikey=#{$api_key}&cmd="
            else
                self.class.base_uri "https://#{$server}:#{$port}#{$httproot}/api/v2?apikey=#{$api_key}&cmd="
            end
        end
    end
	
    def test_connection
	  testConnection = self.class.get("arnold")
	  test = JSON.parse(testConnection.body)
	  @test_result = test["response"]["result"]
    end
	attr_reader :test_result
	
    def timeConvert h
      p, l = h.divmod(12)
      "#{l.zero? ? 12 : l}#{p.zero? ? ":00 A" : ":00 P"}M"
    end
	
	def get_popular_stats
	  getStats = self.class.get("get_home_stats&time_range=#{$time}&stats_type=0")
	  stats = JSON.parse(getStats.body)

		top_movies = 	stats["response"]["data"].find { |elem| elem['stat_id'] == 'top_movies' }
		popular_tv = 	stats["response"]["data"].find { |elem| elem['stat_id'] == 'top_tv' }
		popular_music = stats["response"]["data"].find { |elem| elem['stat_id'] == 'top_music' }
		most_concurrent = stats["response"]["data"].find { |elem| elem['stat_id'] == 'most_concurrent' }
		top_users = stats["response"]["data"].find { |elem| elem['stat_id'] == 'top_users' }

	  begin
		  if $stats.include? "m" && top_movies
			# most popular movie (by play count, by user) aka "Most Watched Movie"

			top_movies = top_movies['rows'][0]

			@pop_movie_id = top_movies["rating_key"]
			@pop_movie = top_movies["title"]
		  end
	  rescue => e
	      $logger.info("Popular Movie Stat failed")
	  end
	  
	  begin
		  if $stats.include? "v" && popular_tv
			# most popular tv show (by play count, by user) aka "Most Watched TV Show"

			popular_tv['rows'][0]

			@pop_tv_id = popular_tv["rating_key"]
			@pop_tv = popular_tv["title"]
		  end
	  rescue => e
	      $logger.info("Popular TV Stat failed")
	  end
	  
	  begin
		  if $stats.include? "a" && popular_music
			# most popular artist (by play count, by user) aka "Most Listened to Artist"

			popular_music = popular_music['rows'][0]

			@pop_artist_id = popular_music["rating_key"]
			@pop_artist = popular_music["title"]
		  end
	  rescue => e
	      $logger.info("Popular Artist Stat failed")
	  end
	  
	  begin
		  if $stats.include? "s" && most_concurrent
			# most concurrent streams

				most_concurrent = most_concurrent['rows'][0]

			@streams = most_concurrent["count"]
		  end
	  rescue => e
	      $logger.info("Most Streams Stat failed")
	  end
	  
	  begin
		  if $stats.include? "u" && top_users
			# top user by duration for all content
			top_user = top_users["rows"][0]["total_duration"]
			hr = top_user / (60 * 60)
			min = (top_user / 60) % 60
			sec = top_user % 60
			@friendly_top_user = "#{ hr } Hours & #{ min } Min's"
		  end
	  rescue => e
	      $logger.info("Top User Stat failed")
	  end
    end
	attr_reader :pop_movie_id
	attr_reader :pop_movie
	attr_reader :pop_tv
	attr_reader :pop_tv_id
	attr_reader :pop_artist_id
	attr_reader :pop_artist
	attr_reader :streams
	attr_reader :friendly_top_user

	def get_popular_day
      getDayOf = self.class.get("get_plays_by_dayofweek&time_range=#{$time}&y_axis=plays")
	  day = JSON.parse(getDayOf.body)

		movie_plays = day["response"]["data"]["series"].find { |elem| elem['name'] == 'Movies' }["data"]
	  
	  begin
		  if $stats.include? "d" && movie_plays
			# most watched day for movies (by duration)
			movie_day_index = movie_plays.index(movie_plays.max)
			case movie_day_index
			when 0
			  @movie_day_name = "Sunday"
			when 1
			  @movie_day_name = "Monday"
			when 2
			  @movie_day_name = "Tuesday"
			when 3
			  @movie_day_name = "Wednesday"
			when 4
			  @movie_day_name = "Thursday"
			when 5
			  @movie_day_name = "Friday"
			when 6
			  @movie_day_name = "Saturday"
			end
		  end
	  rescue => e
	      $logger.info("Most Watched Day for Movies Stat failed")
		end

		tv_plays = day["response"]["data"]["series"].find { |elem| elem['name'] == 'TV' }["data"]

	  begin
		  if $stats.include? "D" && tv_plays
			# most watched day for TV
			tv_day_index = tv_plays.index(tv_plays.max)
			case tv_day_index
			when 0
			  @tv_day_name = "Sunday"
			when 1
			  @tv_day_name = "Monday"
			when 2
			  @tv_day_name = "Tuesday"
			when 3
			  @tv_day_name = "Wednesday"
			when 4
			  @tv_day_name = "Thursday"
			when 5
			  @tv_day_name = "Friday"
			when 6
			  @tv_day_name = "Saturday"
			end
		  end	
	  rescue => e
	      $logger.info("Most Watched Day for TV Stat failed")
	  end		  
	end	
	attr_reader :movie_day_name
	attr_reader :tv_day_name
	
    def get_popular_hour
	  getHourOf = self.class.get("get_plays_by_hourofday&time_range=#{$time}&y_axis=duration")
	  hour = JSON.parse(getHourOf.body)

		movie_plays_hour = hour["response"]["data"]["series"].find { |elem| elem['name'] == 'Movies' }["data"]
	  
	  begin
		  if $stats.include? "t"
			# most popular hour for movies (by duratioon)
			movie_hour_index = movie_plays_hour.index(movie_plays_hour.max)
			@friendly_movie_time = timeConvert(movie_hour_index)
		  end
	  rescue => e
	      $logger.info("Popular Hour for Movies Stat failed")
		end

		tv_plays_hour = hour["response"]["data"]["series"].find { |elem| elem['name'] == 'TV' }["data"]
	  
	  begin
		  if $stats.include? "T"
			# most popular hour for tv (by duration)
			tv_hour_index = tv_plays_hour.index(tv_plays_hour.max)
			@friendly_tv_time = timeConvert(tv_hour_index)
		  end
	  rescue => e
	      $logger.info("Popular Hour for TV Stat failed")
	  end
	end
	attr_reader :friendly_movie_time
	attr_reader :friendly_tv_time
	
    def get_libraries
	  getLibraries = self.class.get("get_libraries")
	  libraries = JSON.parse(getLibraries.body)
	  
	  begin
		  if $stats.include? "A"
			# movie library total
			movie_count = Array.new
			library_stats = libraries["response"]["data"]
				library_stats.each do |section|
					if section['section_type'] == "movie"
						movie_count.push(section['count'])
					end
				end
			@movie_count_sum = movie_count.map!(&:to_i).inject(:+)

			# tv library total (series)
			tv_count = Array.new
			library_stats = libraries["response"]["data"]
				library_stats.each do |section|
					if section['section_type'] == "show"
						tv_count.push(section['count'])
					end
				end
			@tv_count_sum = tv_count.map!(&:to_i).inject(:+)
		  end
	  rescue => e
	      $logger.info("Total Movie and TV Stats failed")
	  end
	  
	  begin
		  if $stats.include? "S"
				# music library total (songs)
			music_count = Array.new
			library_stats = libraries["response"]["data"]
				library_stats.each do |section|
					if section['section_type'] == "artist"
						music_count.push(section['child_count'])
					end
				end
			@music_count_sum = music_count.map!(&:to_i).inject(:+)
		  end
      rescue => e
	      $logger.info("Total Songs Stat failed")
	  end
	end
	attr_reader :movie_count_sum
	attr_reader :tv_count_sum
	attr_reader :music_count_sum

	# still want to add in a count of recently added movies/tv
	# for future reference:
	# sorts = .sort_by {|k,v| v}.reverse
    # average = .reduce(:+).to_f / movie_day.size
    # array string to integers = movie_count.map!(&:to_i).inject(:+)
end

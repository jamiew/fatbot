require 'net/http'
require File.dirname(__FILE__) + "/crack-json.rb" # # require 'rubygems'; require 'json'
require 'cgi'
require 'time'

module TwitterSearch

  class Tweet
    VARS = [:text, :from_user, :to_user, :to_user_id, :id, :iso_language_code, :from_user_id, :created_at, :profile_image_url, :source ]
    attr_reader *VARS
    attr_reader :language
    
    def initialize(opts)
      @language = opts['iso_language_code']
      VARS.each { |each| instance_variable_set "@#{each}", opts[each.to_s] }
    end

    def time_ago
      self.class.time_ago_or_time_stamp Time.parse( @created_at[0..18] )
    end
    def self.time_ago_or_time_stamp(from_time, to_time = Time.now, include_seconds = true, detail = false)
      from_time = from_time.to_time if from_time.respond_to?(:to_time)
      to_time = to_time.to_time if to_time.respond_to?(:to_time)
      distance_in_minutes = (((to_time - from_time).abs)/60).round
      distance_in_seconds = ((to_time - from_time).abs).round
      case distance_in_minutes
        when 0..1           then time = (distance_in_seconds < 60) ? "#{distance_in_seconds} seconds ago" : '1 minute ago'
        when 2..59          then time = "#{distance_in_minutes} minutes ago"
        when 60..90         then time = "1 hour ago"
        when 90..1440       then time = "#{(distance_in_minutes.to_f / 60.0).round} hours ago"
        when 1440..2160     then time = '1 day ago' # 1-1.5 days
        when 2160..2880     then time = "#{(distance_in_minutes.to_f / 1440.0).round} days ago" # 1.5-2 days
        else time = from_time.strftime("%a, %d %b %Y")
      end
      return time_stamp(from_time) if (detail && distance_in_minutes > 2880)
      return time
    end
  end

  class Tweets
    VARS = [:since_id, :max_id, :results_per_page, :page, :query, :next_page]
    attr_reader *VARS

    include Enumerable

    def initialize(opts)
      @results = opts['results'].collect { |each| Tweet.new(each) }
      VARS.each { |each| instance_variable_set "@#{each}", opts[each.to_s] }
    end

    def each(&block)
      @results.each(&block)
    end

    def size
      @results.size
    end
    
    def [](index)
      @results[index]
    end

    def has_next_page?
      ! @next_page.nil?
    end

    def get_next_page
      client = Client.new
      return client.query( CGI.parse( @next_page[1..-1] ) )
    end
  end

  class Client
    TWITTER_API_URL = 'http://search.twitter.com/search.json'
    TWITTER_API_DEFAULT_TIMEOUT = 5
    
    attr_accessor :agent
    attr_accessor :timeout
    
    def initialize(agent = 'twitter-search', timeout = TWITTER_API_DEFAULT_TIMEOUT)
      @agent = agent
      @timeout = timeout
    end
    
    def headers
      { "Content-Type" => 'application/json',
        "User-Agent"   => @agent }
    end
    
    def query(opts = {})
      url       = URI.parse(TWITTER_API_URL)
      url.query = sanitize_query(opts)

      req  = Net::HTTP::Get.new(url.path)
      http = Net::HTTP.new(url.host, url.port)
      http.read_timeout = timeout
      
      json = http.start { |http|
        http.get("#{url.path}?#{url.query}", headers)
      }.body
      Tweets.new Crack::JSON.parse(json)
    end

    private

      def sanitize_query(opts)
        if opts.is_a? String
          "q=#{CGI.escape(opts)}" 
        elsif opts.is_a? Hash
          "#{sanitize_query_hash(opts)}"
        end
      end

      def sanitize_query_hash(query_hash)
        query_hash.collect { |key, value| 
          "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}" 
        }.join('&')
      end
  
  end

end

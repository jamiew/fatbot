#!/usr/bin/env ruby
# this is jamiew's IRC bot for #fatlab
# his name is DUBTRON 9000
# http://jamiedubs.com
#
# dependencies: isaac, sequel, jnunemaker-twitter, mechanize

require 'time'
require 'open-uri'

require 'rubygems'
require 'isaac'
require 'mechanize' # for !swineflu
require 'twitter' # for !twitter posting
require 'json'

%w{/vendor /vendor/utils}.collect{ |dir| $:.unshift File.dirname(__FILE__)+dir }
%w{twitter_search flickraw}.collect{ |lib| require(lib).to_s }

# require 'sequel'
# DB = Sequel.sqlite('irc.db')
$link_store ||= {}
$twitter ||= TwitterSearch::Client.new

configure do |c|
  c.nick     = "dubtr0n"
  c.realname = "jamiew's bot"
  c.server   = "irc.freenode.net"
  c.port     = 6667
  c.verbose  = false
  c.version   = "FATBOT <http://github.com/jamiew/fatbot>"
end

# NickServ-based security: simple check for FAT Lab fellows
helpers do
  def ops?(nick)
   ['jamiew','ttttbx','fi5e','randofo','bekathwia','MissSubmarine','gleuch','agoasi','monki','bennett4senate'].include?(nick)
  end
end


# CONNECT
on :connect do
  join "#fatlab", "#knowyourmeme", "#tumblrs", "#diaspora-dev", "#vhx", "#ofdev", "#nerdbeers"
end

# echo things like "quote this: some text"
on :channel, /^\!echo (.*)/i do
  msg channel, "#{match[0]}"
end

# print a randomly generated meme phrase using Automeme API by @inky
on :channel, /^\!meme$/i do
 meme = open("http://meme.boxofjunk.ws/moar.txt?lines=1").read.chomp rescue 'ERROR: could not reach AutoMeme :-('
 msg channel, meme
end

# print a hipster-meme quote
on :channel, /^\!hipster$/i do
  meme = open("http://meme.boxofjunk.ws/moar.txt?lines=1&vocab=hipster").read.chomp rescue 'ERROR: could not reach AutoMeme :-('
  msg channel, meme
end

# print a Kanye quote from QUOTABLE KANYE by @jamiew, http://jamiedubs.com/quotable-kanye/
on :channel, /^\!kanye$/i do
 quote = open("http://jamiedubs.com/quotable-kanye/api.txt").read.chomp rescue 'ERROR: could not reach Kanye Quote DB :-('
 msg channel, quote
end

# post to a shared twitter account
# keep your settings (username, password) in twitter.yml
on :channel, /^\!twitter (.*)/i do
  return unless ops?(nick)
  cred = YAML.load(File.open('twitter.yml'))
  begin
    httpauth = Twitter::HTTPAuth.new(cred['username'], cred['password'])
    base = Twitter::Base.new(httpauth)
    base.update(match[0])
    msg channel, "*** affirmative #{nick}, posted to #{cred['username'].inspect}"
  rescue
    msg channel, "Failed to update Twitter :( error => #{$!}"
  end
end


# print results of Twitter.com search for a phrase
on :channel, /^\!search_twitter (.*)/i do
  begin
    case match[0]
      when /\:all/
        _query = match[0].gsub(":all",''); _rindex = -1
      else
        _query = match[0]; _rindex = 2
    end

    result = $twitter.query :q => "#{_query}"
    # msg channel, "search_twitter: #{_query} (#{result.size} results)"
    result[0.._rindex].collect { |i|
      msg channel, "'#{i.text}' - #{i.from_user} (#{i.time_ago})"
    }
  rescue Exception => e
    msg channel, "search_twitter: (#{e.message}) - twitter timeout."
  end
end

# give you a taco. via gerry
on :channel, /^\!taco$/i do
  tacos = ['carnitas', 'barbacoa', 'fish', 'shrimp', 'swineflu']
  # raw ["ACTION #{channel} :/me ", "gives #{nick} a #{tacos[(rand*tacos.length).floor]} taco"].join
  raw ["NOTICE #{channel} :", "gives #{nick} a #{tacos[(rand*tacos.length).floor]} taco"].join
end

# change the topic (for people in ops? but without real ops)
on :channel, /^\!topic (.*)/i do
   topic(channel, "#{match[0]} [#{nick}]") if ops?(nick)
end

# swine flu report (USA only for now)
# data is from Rhiza Labs, LLC's (http://www.rhizalabs.com/) FluTracker:
# http://flutracker.rhizalabs.com/
# data is released under Creative Commons Attribution-Noncommercial-Share Alike 3.0 United States License.
on :channel, /^\!(swineflu|pigflu)$/i do
  url, shorturl, totals, usdata = "http://flutracker.rhizalabs.com/flu/gmap.html", "http://bit.ly/9wwcR", [], 0
  begin
    page = Mechanize.new.get(url)
    aggregates = (page/'script').map { |i| i.content }

    if aggregates[5] =~ /(\d+)\/aggregates.js/
      timedate = TwitterSearch::Tweet.time_ago_or_time_stamp( Time.parse($1) )
    end

    aggurl = "http://flutracker.rhizalabs.com/flu/#{$1}/aggregates.js"
    fludata = open(aggurl, 'User-Agent' => 'Fatbot')
    fludata = Crack::JSON.parse(fludata.read)
    fludata.each do |x|
      if x["country"] == "US"
        usdata = x
      end
    end

    cases = usdata["cases"]
    fatal = usdata["Fatal"]
    text = "U.S. Human Cases of H1N1 Flu Infection (As of #{timedate}): Cases: #{cases} - Deaths: #{fatal} -- http://flutracker.rhizalabs.com/"

  rescue Exception => e
    text = "Exception: #{e.message}"
  end
  msg channel, text
end

# do URL detection & logging -- idea via sh1v
on :channel, /http\:\/\/(.*)\s?/ do
  $link_store[channel] ||= []
  $link_store[channel] << { :url => match[0], :nick => nick, :date => Time.now }
  $link_store[channel].shift if $link_store[channel].size > 10
end

# echo back collected URLs
on :channel, /^\!(links|lionks)/i do
  if $link_store[channel]
    # msg channel, "Most recent links (#{$link_store[channel].size} total)"
    urls = $link_store[channel].map { |l| "http://#{l[:url]} posted by #{l[:nick]}" } || []
    urls.uniq.reverse[0..2].each { |url| msg channel, url }
  else
    msg channel, "No URLs yet!"
  end
end

# generate IRC stats using pisg
on :channel, /^\!stats$/i do
  begin
    system("#{File.dirname(__FILE__)}/../pisg/pisg &")
    msg channel, "Rebuilding stats for this channel: http://173.45.226.44/irc/#{channel.to_s.gsub('#','').downcase}.html"
  rescue
    msg channel, "Error generating stats: #{$!}"
  end
end

# print number of open issues for specified repository
# usage: "!issues jamiew/git-friendly"
# adds some default repos for specific channels
on :channel, /^!issues ?(.*)$/i do
  begin

    repo = match[0] && !match[0].empty? && match[0] || nil
    repo ||= 'diaspora/diaspora' if channel =~ /diaspora/

    # TODO handle blank repo more gracefully than this
    raise "You need to specify a repository like 'jamiew/fatbot' as an argument" if repo.nil? || repo.empty?

    page = Mechanize.new.get("https://github.com/api/v2/json/issues/list/#{repo}/open")
    json = JSON.parse(page.body)
    issues = json['issues']

    stats = {:pull_requests => 0, :features => 0, :bugs => 0, :other => 0}
    issues.each do |issue|
      if issue['pull_request_url']
        stats[:pull_requests] += 1
      elsif issue['labels'].include?('feature')
        stats[:features] += 1
      elsif issue['labels'].include?('bug')
        stats[:bugs] += 1
      else
        stats[:other] += 1
      end
    end

    url = "https://github.com/#{repo}/issues"
    msg channel, "#{issues.length} open issues for #{repo}: #{stats.sort_by{|k,v| v }.reverse.map{|k,v| "#{v} #{k}" }.join(', ')} #{url}"
  rescue
    msg channel, "Issues getting issues: #{$!}"
  end
end

on :channel, /^!(fb|facebook)$/i do
  msg channel, "DEPRECATED, type \"$fb\" instead. That syntax works for any stock ticker"
end

on :channel, /^\$(.*)$/i do
  ticker = match[0].to_s.upcase
  url = "http://download.finance.yahoo.com/d/quotes.csv?s=#{ticker}&f=sb2b3jk"
  begin
    raw = open(url).read.chomp
    data = raw.split(',')
    msg channel, "Current $#{ticker} price: #{data[1]} -- http://www.google.com/finance?q=#{ticker}"
  rescue
    msg channel, "Error trying to fetch data for #{ticket}: #{$!.inspect}"
  end
end



# lastly, do logging
# from http://github.com/jamie/ircscribe/
# on :channel, /.*/ do
#   msg = message.chomp
#   puts "#{channel} <#{nick}> #{msg}"
#   # DB[:messages] << {:channel => channel, :nick => nick, :message => msg, :at => Time.now}
# end


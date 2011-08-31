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
  c.verbose  = true
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
  join "#fatlab", "#knowyourmeme", "#tumblrs", "#diaspora-dev"
end

# echo things like "quote this: some text"
on :channel, /^\!echo (.*)/i do
  msg channel, "#{match[0]}" 
end

# print a randomly generated meme phrase using Automeme API by @inky
on :channel, /^\!meme/i do
 meme = open("http://meme.boxofjunk.ws/moar.txt?lines=1").read.chomp rescue 'ERROR: could not reach AutoMeme :-('
 msg channel, meme
end

# print a Kanye quote from QUOTABLE KANYE by @jamiew, http://jamiedubs.com/quotable-kanye/
on :channel, /^\!kanye/i do
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
on :channel, /^\!taco/i do
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
on :channel, /^\!(swineflu|pigflu).*/i do
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
on :channel, /^\!stats/i do
  begin
    system("#{File.dirname(__FILE__)}/../pisg/pisg &")
    msg channel, "stats regenerated for channel, http://173.45.226.44/irc/#{channel.to_s.gsub('#','').downcase}.html"
  rescue
    msg channel, "Error generating stats: #{$!}"
  end
end

# lastly, do logging
# from http://github.com/jamie/ircscribe/
# on :channel, /.*/ do
#   msg = message.chomp
#   puts "#{channel} <#{nick}> #{msg}"
#   # DB[:messages] << {:channel => channel, :nick => nick, :message => msg, :at => Time.now}
# end

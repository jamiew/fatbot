#!/usr/bin/env ruby
# this is jamiew's IRC bot for #fatlab
# his name is DUBTRON 9000
# http://jamiedubs.com
#
# dependencies: isaac, sequel, jnunemaker-twitter
%w{/vendor /vendor/utils}.collect{|ld|$:.unshift File.dirname(__FILE__)+ld}

require 'rubygems'
require 'isaac'
require 'time'

require 'open-uri'  # for !meme, !swineflu
require 'mechanize' # for !swineflu
#gem 'jnunemaker-twitter', :lib => 'twitter' for !twitter
require 'twitter'
puts %w{twitter_search flickraw}.collect{|ld|ld+': '+require(ld).to_s}#.join(", ")

# require 'sequel'
# DB = Sequel.sqlite('irc.db')
$link_store ||= {}
$twitter ||= TwitterSearch::Client.new

configure do |c|
  c.nick     = "dubtron"
  c.realname = "jamiew's bot"
  c.server   = "irc.freenode.net"
  c.port     = 6667
end


# just a simple check for FAT Lab fellows
# count on NickServ for security :x
# UPDATE: fuck it, allow everyone. FREE CULTURE BABY YEAH
def ops?(nick)
  # ['jamiew','ttttbx','fi5e','randofo','bekathwia','Geraldine','Geraldine_'].include?(nick)
  true
end


# CONNECT
on :connect do
  # join "#tumblrs", "#fatlab", "#rboom"
  join "#fatlab"
end




# echo things like "quote this: some text"
#TODO: make just if via a private msg from ops or something
on :channel, /^\!echo (.*)/i do
  msg channel, "#{match[0]}" 
  # msg channel, "#{match[0]} by #{nick}"
end

# give me a meme using inky's automeme ENTERPRISE API
on :channel, /^\!meme/i do
 meme = open("http://meme.boxofjunk.ws/moar.txt?lines=1").read.chomp
 msg channel, meme
end

# print a Kanye quote from THE QUOTABLE KANYE, http://jamiedubs.com/quotable-kanye/
on :channel, /^\!kanye/i do
 quote = open("http://jamiedubs.com/quotable-kanye/api.txt").read.chomp
 msg channel, quote
end

# post to a shared twitter account
on :channel, /^\!twitter (.*)/i do
  cred = YAML.load(File.open('twitter.yml'))

  httpauth = Twitter::HTTPAuth.new(cred['username'], cred['password'])
  base = Twitter::Base.new(httpauth)
  base.update(match[0])

  msg channel, "*** affirmative #{nick}, posted to #{cred['username'].inspect}"
end


# ..
on :channel, /^\!search_twitter (.*)/i do
  begin
    case match[0]
      when /\:all/
        _query = match[0].gsub(":all",''); _rindex = -1
      else
        _query = match[0]; _rindex = 2
    end

    result = $twitter.query :q => "#{_query}"
    msg channel, "search_twitter: #{_query} (#{result.size} results)"
    result[0.._rindex].collect { |i|
      msg channel, "'#{i.text}' - #{i.from_user} (#{i.time_ago})"
    }
  rescue Exception => e
    msg channel, "search_twitter: (#{e.message}) - twitter timeout."
  end
end

# ..
on :channel, /^\!fatlab_twitter/i do
  result = $twitter.query :q => "fatlab" # '#fatlab' ?
  msg channel, "fatlab_twitter: (#{result.size} results)"
  result.collect { |i| msg channel, "'#{i.text}' - #{i.from_user} (#{i.time_ago})" }
end


# give you a taco. via gerry
# TODO: we need more tacos
on :channel, /^\!taco/i do
  tacos = ['carnitas', 'barbacoa', 'fish', 'shrimp', 'swineflu']
  # raw ["ACTION #{channel} :/me ", "gives #{nick} a #{tacos[(rand*tacos.length).floor]} taco"].join
  raw ["NOTICE #{channel} :", "gives #{nick} a #{tacos[(rand*tacos.length).floor]} taco"].join
end


# change the topic by proxy (for bot-ops)
on :channel, /^\!topic (.*)/i do
   topic(channel, "#{match[0]} [#{nick}]") if ops?(nick)
end


# swine flu report (USA only for now)
# data is from Rhiza Labs, LLC's (http://www.rhizalabs.com/) FluTracker
# http://flutracker.rhizalabs.com/
# http://flutracker.rhizalabs.com/flu/downloads.html
# data is released under Creative Commons Attribution-Noncommercial-Share Alike 3.0 United States License. 
on :channel, /^\!(swineflu|pigflu).*/i do
  url, shorturl, totals, usdata = "http://flutracker.rhizalabs.com/flu/gmap.html", "http://bit.ly/9wwcR", [], 0
  begin
    page = WWW::Mechanize.new.get(url)
    aggregates = (page/'script').map { |i| i.content }
    
    
    #initialize('200906081850/aggregates.js', '200906081850/states.js', '200906081850');

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


# do URL detection & logging, idea vi sh1v
on :channel, /http\:\/\/(.*)\s?/ do
  $link_store[channel] ||= []
  $link_store[channel] << { :url => match[0], :nick => nick, :date => Time.now }
  $link_store[channel].shift if $link_store[channel].size > 10
  puts "URL: #{match[0]} by #{nick} : #{$link_store[channel].size}"
end

on :channel, /^\!(links|bookmarks).*/i do
  if $link_store[channel]
    msg channel, "last urls: (#{$link_store[channel].size})"
    $link_store[channel].collect { |l| msg channel, "#{l[:url]} by #{l[:nick]}" }
  else
    msg channel, "no urls.."
  end
end


# lastly, do logging
# from http://github.com/jamie/ircscribe/
# on :channel, /.*/ do
#   msg = message.chomp
#   puts "#{channel} <#{nick}> #{msg}"
#   # DB[:messages] << {:channel => channel, :nick => nick, :message => msg, :at => Time.now}
# end

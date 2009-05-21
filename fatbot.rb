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

require 'open-uri'  # for !meme
require 'mechanize' # for !swineflu
#gem 'jnunemaker-twitter', :lib => 'twitter' for !twitter
puts %w{twitter_search flickraw}.collect{|ld|ld+': '+require(ld).to_s}#.join(", ")

# require 'sequel'
# DB = Sequel.sqlite('irc.db')
$link_store ||= []
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
  cred = YAML.load('twitter.yml')
  # TODO do some stuff with twitter gem
  msg channel, "*** posting announcement by #{nick} to http://twitter.com/fffffat ..."
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
# the CDC has a nice report with latest US stats, but not global
on :channel, /^\!(swineflu|pigflu).*/i do
  url, shorturl, totals = "http://www.cdc.gov/h1n1flu/update.htm", "http://bit.ly/18L44G", []
  begin
    page = WWW::Mechanize.new.get(url)
    totals = (page/'.mSyndicate strong').map { |i| i.content }[1..4]
    timedate = (page/'.mSyndicate span').map { |i| i.content }[2]
    totals[1].gsub!(/\t/,'')
    raise "no totals" if totals.size < 3
    
    if timedate =~ /\(As of (.+)\)/
     timedate = TwitterSearch::Tweet.time_ago_or_time_stamp( Time.parse($1) )
    end
     
    text = "U.S. Human Cases of H1N1 Flu Infection (As of #{timedate}): #{totals[1..2].join(", ")} -- http://www.cdc.gov/h1n1flu/"
  rescue Exception => e
    text = (e.message == "no totals") ? "no totals data! #{totals.inspect}" : "Exception: #{e.message}"
  end
  msg channel, text
end


# do URL detection & logging, idea vi sh1v
on :channel, /http\:\/\/(.*)\s?/ do
  $link_store << { :url => match[0], :nick => nick, :date => Time.now }
  $link_store.shift if $link_store.size > 10
  puts "URL: #{match[0]} by #{nick} : #{$link_store.size}"
end

on :channel, /^\!(links|bookmarks).*/i do
  msg channel, "last urls: (#{$link_store.size})"
  $link_store.collect { |l| msg channel, "#{l[:url]} by #{l[:nick]}" }
end


# lastly, do logging
# from http://github.com/jamie/ircscribe/
# on :channel, /.*/ do
#   msg = message.chomp
#   puts "#{channel} <#{nick}> #{msg}"
#   # DB[:messages] << {:channel => channel, :nick => nick, :message => msg, :at => Time.now}
# end

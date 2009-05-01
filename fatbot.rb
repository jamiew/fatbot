#!/usr/bin/env ruby
# this is jamiew's IRC bot for #fatlab
# his name is DUBTRON 9000
# http://jamiedubs.com
#
# dependencies: isaac, sequel, jnunemaker-twitter

require 'rubygems'
require 'isaac'

require 'open-uri'  # for !meme
require 'mechanize' # for !swineflu
#gem 'jnunemaker-twitter', :lib => 'twitter' for !twitter

# require 'sequel'
# DB = Sequel.sqlite('irc.db')

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
  # join "#tumblrs", "#fatlab"
  join "#fatlab"
end




# echo things like "quote this: some text"
#TODO: make just if via a private msg from ops or something
on :channel, /^\!echo (.*)/ do
  msg channel, "#{match[0]}" 
  # msg channel, "#{match[0]} by #{nick}"
end

# give me a meme using inky's automeme ENTERPRISE API
on :channel, /^\!meme/ do
 meme = open("http://meme.boxofjunk.ws/moar.txt?lines=1").read.chomp
 msg channel, meme
end

# post to a shared twitter account
on :channel, /^\!twitter (.*)/ do
  cred = YAML.load('twitter.yml')
  # TODO do some stuff with twitter gem
  msg channel, "*** posting announcement by #{nick} to http://twitter.com/fffffat ..."
end 

# give you a taco. via gerry
# TODO: we need more tacos
# FIXME: how to do actions? not sure if isaac handles
on :channel, /^\!taco/ do
  tacos = ['carnitas', 'barbacoa', 'fish', 'shrimp']
  msg channel, "/me gives #{nick} a #{tacos[(rand*tacos.length).floor]} taco"
end

# change the topic by proxy (for bot-ops)
on :channel, /^\!topic (.*)/ do
   topic(channel, "#{match[0]} [#{nick}]") if ops?(nick)
end

# swine flu report (USA only for now)
# the CDC has a nice report with latest US stats, but not global
on :channel, /^\!(swineflu|pigflu).*/ do
  url, shorturl = "http://www.cdc.gov/h1n1flu/index.htm", "http://bit.ly/eeat8"
  agent = WWW::Mechanize.new # TODO: use a global agent & set user-agent to FATBOT YEAH
  page = agent.get(url)
  totals = (page/'#situationupdate strong')
  raise "no totals data!" if totals.nil? or totals[1].nil? or totals[2].nil?
  text = "Swine Flu USA: #{totals[1].content},#{totals[2].content} -- #{shorturl}"
  msg channel, text
end 


# do URL detection & logging, idea vi sh1v
on :channel, /http\:\/\/(.*)\s?/ do
  puts "URL: #{match[0]} by #{nick}"
end

# lastly, do logging
# from http://github.com/jamie/ircscribe/
# on :channel, /.*/ do
#   msg = message.chomp
#   puts "#{channel} <#{nick}> #{msg}"
#   # DB[:messages] << {:channel => channel, :nick => nick, :message => msg, :at => Time.now}
# end

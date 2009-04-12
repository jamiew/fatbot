#!/usr/bin/env ruby
# this is jamiew's IRC bot for #fatlab
# his name is DUBTRON 9000
# http://jamiedubs.com

require 'rubygems'
require 'isaac'
require 'open-uri'


configure do |c|
  c.nick     = "dubtron"
  c.realname = "jamiew's bot"
  c.server   = "irc.freenode.net"
  c.port     = 6667
end


# just a simple superuserish check
# count on NickServ for security :x
def ops?(nick)
  ['jamiew','ttttbx','fi5e','randofo','bekathwia','Geraldine_'].include?(nick)
end


# CONNECT
on :connect do
  join "#tumblrs", "#fatlab"
end


# log all text
#on :channel, /.*/ do
#  open("#{channel}.log", "a") do |log|
#    log.puts "#{nick}: #{message}"
#  end
#  puts "#{channel}: #{nick}: #{message}"
#end


# echo things like "quote this: some text"
on :channel, /^\!echo (.*)/ do
  msg channel, "#{match[0]}" 
  # msg channel, "#{match[0]} by #{nick}"
end

# private echo for ops
# TODO


# give me a meme
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
on :channel, /^\!taco/ do
  tacos = ['carnitas', 'barbacoa', 'fish', 'shrimp']
  msg channel, "/me gives #{nick} a #{tacos[(rand*tacos.length).floor]} taco"
end

# change the topic (ops)
on :channel, /^!topic (.*)/ do
  msg channel, "/topic #fatlab #{match[0]}" if ops?(nick)
end


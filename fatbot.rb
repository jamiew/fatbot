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

# give me a meme
on :channel, /^\!meme/ do
 meme = open("http://meme.boxofjunk.ws/moar.txt?lines=1").read.chomp
 msg channel, meme
end


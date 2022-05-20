PREFIX = '.'

DISCORD_TOKEN = File.read("./discord_token").chomp
DISCORD_CLIENT_ID = File.read("./discord_client_id").chomp

require 'bundler'
Bundler.setup(:default, :ci)

require 'json'

puts "\n"
puts "DISCORD_TOKEN=#{DISCORD_TOKEN}"
puts "DISCORD_CLIENT_ID=#{DISCORD_CLIENT_ID}"
puts "\n"

require 'rest-client'
ENV["DISCORDRB_NONACL"] = "true"
require 'discordrb' # https://www.rubydoc.info/gems/discordrb/3.2.1/

$bot = Discordrb::Bot.new(token: DISCORD_TOKEN, client_id: DISCORD_CLIENT_ID)

$bot.message(start_with: PREFIX + 'ping') do |event|
    event.respond 'Pong!'
end

$bot.run
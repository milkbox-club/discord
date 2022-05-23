PREFIX = '/'

MILKBOX_URL = "https://milkbox.club/api"
MILKBOX_APPLICATION_ID = File.read("./milkbox_application_id").chomp

WATCH_SLEEP_PERIOD = 5 # seconds

DISCORD_TOKEN = File.read("./discord_token").chomp
DISCORD_CLIENT_ID = File.read("./discord_client_id").chomp
DISCORD_SERVER_ID = File.read("./discord_server_id").chomp

require 'bundler'
Bundler.setup(:default, :ci)

require 'uri'
require 'http'
require 'json'
require 'date'

puts "\n"
puts "DISCORD_TOKEN=#{DISCORD_TOKEN}"
puts "DISCORD_CLIENT_ID=#{DISCORD_CLIENT_ID}"
puts "DISCORD_CLIENT_ID=#{DISCORD_SERVER_ID}"
puts "MILKBOX_APPLICATION_ID=#{MILKBOX_APPLICATION_ID}"
puts "\n"

require 'rest-client'
ENV["DISCORDRB_NONACL"] = "true"
require 'discordrb' # https://www.rubydoc.info/gems/discordrb/3.2.1/

class String
    def encap(a = '', b = '')
        return a + self + (b == '' ? a : b)
    end

    def quote
        return self.encap('"')
    end
end

def dismantle_tags(str)
    str.scan(/\[(.*?)\]/).each do |match|
        payload = match.first.split(':')[1..-1].join(':')
        str.gsub!(match.first.encap('[', ']'), payload.quote)
    end
end

def get_recent_posts()
    begin
        url = "#{MILKBOX_URL}/getRecentPosts?application_id=#{MILKBOX_APPLICATION_ID}"
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(url)
        response = http.request(request)
        if response.code == "200"
            return JSON.parse(response.body)
        else
            raise StandardError.new
        end
        return data
    rescue => e
        puts e.message
        return {}
    end
end

def embed_latest_posts(channel, cutoff_time)
    for post in get_recent_posts() do
        post_time = Time.parse(post["posted_at"])
        difference = cutoff_time - post_time
        puts ["post=#{post["id"]}", "post_time=#{post_time}", "cutoff_time=#{cutoff_time}", "difference=#{difference}"].inspect
        if ((difference > 0) && (difference < WATCH_SLEEP_PERIOD))
            channel.send_embed do |embed|
                embed.title = post["contents"]["title"]
                embed.description = dismantle_tags(post["contents"]["body"])
                embed.author = Discordrb::Webhooks::EmbedAuthor.new(
                    name: post["author"]["alias"],
                    icon_url: "#{MILKBOX_URL}/getAvatar?application_id=#{MILKBOX_APPLICATION_ID}&user_id=#{post["author"]["id"]}"
                )
                embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: post["tags"].join(", "))
            end
        end
    end
end

def watch_api(channel)
    last_check_time = Time.now
    Thread.new do
        while $watching
            sleep(WATCH_SLEEP_PERIOD)
            embed_latest_posts(channel, last_check_time)
            last_check_time = Time.now
        end
    end
end

$bot = Discordrb::Bot.new(token: DISCORD_TOKEN, client_id: DISCORD_CLIENT_ID, intents: [:server_messages])

$bot.register_application_command(:ping, 'Ping!', server_id: DISCORD_SERVER_ID)

$bot.application_command(:ping) do |event|
    event.respond(content: 'Pong!')
end

$bot.register_application_command(:debug, 'Debug!', server_id: DISCORD_SERVER_ID)

$bot.application_command(:debug) do |event|
    # ...
end

$bot.register_application_command(:start, 'Start watching!', server_id: DISCORD_SERVER_ID)

$bot.application_command(:start) do |event|
    event.respond(content: 'Started watchers!')
    $watching = true
    watch_api(event.channel)
end

$bot.register_application_command(:stop, 'Stop watching!', server_id: DISCORD_SERVER_ID)

$bot.application_command(:stop) do |event|
    event.respond(content: 'Stopped watchers!')
    $watching = false
end

$bot.run
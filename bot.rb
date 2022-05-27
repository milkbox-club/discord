PREFIX = '/'
PLAY_EMOJI = "<:media_play:979715938683326464>"
PAUSE_EMOJI = "<:media_pause:979716018312208456>" 

MILKBOX_URL = "https://milkbox.club/api"
MILKBOX_APPLICATION_ID = File.read("./milkbox_application_id").chomp
MILKBOX_IMAGE_URL = "https://raw.githubusercontent.com/milkbox-club/milkbox/main/data/images/carton.png"

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
    return str
end

def get_avatar_url(user_id)
    return "#{MILKBOX_URL}/getAvatar?application_id=#{MILKBOX_APPLICATION_ID}&user_id=#{user_id}"
end

def get_users_by_alias(query)
    begin
        url = "#{MILKBOX_URL}/getUsersByAlias?application_id=#{MILKBOX_APPLICATION_ID}&alias=#{query}"
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
                    name: post["author"]["alias"], icon_url: get_avatar_url(post["author"]["id"])
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

def format_player_string(player)
    body = "#{player["paused"] ? PAUSE_EMOJI + " Last played" : PLAY_EMOJI + " Now playing"} "
    body += "**#{player["track"]}** by **#{player["artist"]}**\n"
    body += "on **#{player["album"]}**"
    body += " (*#{player["collection"]}*)" if player["collection"] != player["album"]
    return body
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

$bot.register_application_command(:milkbox, 'See what your friends are listening to!', server_id: DISCORD_SERVER_ID) do |cmd|   
    cmd.string('alias', 'Milkbox alias')
end

# "player": {
#   "artist": "A Winged Victory for the Sullen",
#   "track": "The Haunted Victorian Pencil",
#   "album": "The Undivided Five",
#   "collection": "The Undivided Five",
#   "paused": true # ⏸⏵︎

$bot.application_command(:milkbox) do |event|
    milkbox_users = get_users_by_alias(event.options['alias'])
    if milkbox_users.empty?
        event.respond(content: "Could not match '#{event.options['alias']}' to any users")
    else
        event.respond(embeds: milkbox_users.map { |user|
            embed = Discordrb::Webhooks::Embed.new
            embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: MILKBOX_IMAGE_URL)
            embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: user["alias"], icon_url: get_avatar_url(user["user_id"]))
            embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "#{user["contributions"]["count"]} contribution(s)")
            embed.description = format_player_string(user["player"])
            embed
        })
    end
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
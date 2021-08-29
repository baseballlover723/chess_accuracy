require "http/client"
require "uri/params"
require "myhtml"

require "../active_session"
require "../dtos/color"
require "../dtos/proto_game_color"
require "../dtos/proto_game"
require "../fiber_pool"
require "../timer"

class ArchiveClient
  URL             = "https://www.chess.com/games/archive/"
  DEFAULT_OPTIONS = {"rated" => "rated"}
  GAMES_PER_PAGE = 50
  # CONCURRENT_REQUESTS = 16
  CONCURRENT_REQUESTS = 4
  # CONCURRENT_REQUESTS = 1

  @@pool = FiberPool(String, HTTP::Client::Response).new(CONCURRENT_REQUESTS)

  # returns full game objects, id, time_control, your color, accuracy, rating, opening, datetime, moves, name, etc... (full db object, get more info from offical api)
  def self.get_games(username : String, options = {} of String => String) : Channel(ProtoGame)
    options = DEFAULT_OPTIONS.merge(options)
    games = [] of ProtoGame
    page = 1

    return_channel = Channel(ProtoGame).new

    html_to_proto_game_channel = Channel(ProtoGame).new
    buffered_proto_games = [] of ProtoGame

    spawn do
      html_calls(html_to_proto_game_channel, username, options, page)
    end

    spawn do
      while !html_to_proto_game_channel.closed?
        proto_game = html_to_proto_game_channel.receive
        # puts "recieved protogame: #{proto_game.id}"
        buffered_proto_games << proto_game
      end
    end



    # loop do
    #   channel = Channel(Array(ProtoGame)).new
    #   any_not_full = false

    #   {% for offset in 0...CONCURRENT_REQUESTS %}
    #     spawn_call(username, options, page, channel, {{offset}})
    #   {% end %}

    #   {% for offset in 0...CONCURRENT_REQUESTS %}
    #     new_games = channel.receive
    #     games.concat(new_games)
    #     any_not_full = true if new_games.size != 50
    #   {% end %}

    #   page += CONCURRENT_REQUESTS

    #   # new_games = get_page(username, options, page)
    #   # page += 1

    #   # games.concat(new_games)

    #   break if any_not_full
    #   # break
    #   # break if new_games.size != 50
    # end

    # TODO doesn't use full bandwidth for a single user, probably properly thottles multiple users though
    # something something, maybe make a queue function on fiber pool, returning the return channel?
    # something something, spwan a thread, and
    # loop do
    #   new_games = get_page(username, options, page)
    #   page += 1
    #   games.concat(new_games)
    #   break if new_games.size != 50
    # end

    # games
    return_channel
  end

  macro html_calls(html_to_proto_game_channel, username, options, page)
    proto_game_count_channel = Channel(UInt64).new
    loop do
      {% for offset in 0...CONCURRENT_REQUESTS %}
        spawn_call({{html_to_proto_game_channel}}, proto_game_count_channel, {{username}}, {{options}}, {{page}}, {{offset}})
      {% end %}
      %game_count = 0
      {% for offset in 0...CONCURRENT_REQUESTS %}
      cc = proto_game_count_channel.receive
      puts "recieve #{cc} games"
        %game_count += cc
      {% end %}
      # break if %game_count < {{GAMES_PER_PAGE * CONCURRENT_REQUESTS}}
      break
      page += CONCURRENT_REQUESTS
    end
    puts "closing html_to_proto_game_channel"
    {{html_to_proto_game_channel}}.close
  end

  macro spawn_call(return_channel, proto_game_count_channel, username, options, page, offset)
    proc = -> (page : Int32) do
      spawn do 
        get_page({{return_channel}}, {{proto_game_count_channel}}, {{username}}, {{options}}, page + {{offset}})
      end
    end
    proc.call({{page}})
    # Fiber.yield
  end

  # 200 is good, 302 means session is expired
  private def self.get_page(return_channel : Channel(ProtoGame), proto_game_count_channel : Channel(UInt64), username : String, options : Hash(String, String), page : Int32) : Nil
    return [] of ProtoGame if page >= 101 # archive limit
    options = options.merge({"page" => page.to_s})
    url = URL + username + "?" + URI::Params.encode(options)
    puts "getting url: #{url}" # DEBUG
    response = Timer.exclude(:processing) do
      Timer.time(:http) do
        @@pool.run(url) do |url|
          HTTP::Client.get(url, headers: ActiveSession.get.headers)
        end
      end
    end
    puts response.status_code # DEBUG
    puts response.inspect if response.status_code == 302
    Timer.time(:html_processing) do
      number_of_proto_games = parse_html_games(return_channel, response.body)
      proto_game_count_channel.send(number_of_proto_games)
    end
  end

  # return a list of proto game objects (id, p1 accurcy, p2 accuarcy)
  private def self.parse_html_games(return_channel : Channel(ProtoGame), html : String) : UInt64
    html = Myhtml::Parser.new(html)
    html_games = html.css(".archive-games-table tbody tr")
    html_games.each { |tr| parse_html_game(return_channel, tr) }
    html_games.size
  end

  private def self.parse_html_game(return_channel : Channel(ProtoGame), row) : Nil
    link = URI.parse(row.css(".archive-games-background-link").first.attribute_by("href").as(String))
    link.query = ""
    _, _, time_class, id = link.path.split("/")
    id = id.to_i64(whitespace: true)

    white_user, black_user = row.css(".archive-games-users .user-username-component").map(&.inner_text).map(&.strip)

    accuracies = row.css(".archive-games-analyze-cell div").map(&.inner_text).map(&.to_f64(whitespace: true))

    accuracies = [nil, nil] if accuracies.empty?
    white_accuracy, black_accuracy = accuracies

    moves = row.css(".archive-games-analyze-cell").first.as(Myhtml::Node)
      .flat_right.as(Myhtml::Node).flat_right.as(Myhtml::Node)
      .css("span").first.as(Myhtml::Node)
      .inner_text.strip.to_u16

    white = ProtoGameColor.new(color: Color::White, username: white_user, accuracy: white_accuracy)
    black = ProtoGameColor.new(color: Color::Black, username: black_user, accuracy: black_accuracy)
    proto_game = ProtoGame.new(id: id, time_class: time_class, link: link.to_s, moves: moves, white: white, black: black)
    return_channel.send(proto_game)
  end
end

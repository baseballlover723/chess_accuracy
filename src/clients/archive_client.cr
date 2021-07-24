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
  # CONCURRENT_REQUESTS = 16
  CONCURRENT_REQUESTS = 4
  # CONCURRENT_REQUESTS = 1

  @@pool = FiberPool(String, HTTP::Client::Response).new(CONCURRENT_REQUESTS)

  # returns full game objects, id, time_control, your color, accuracy, rating, opening, datetime, moves, name, etc... (full db object, get more info from offical api)
  def self.get_games(username : String, options = {} of String => String) : Array(ProtoGame)
    options = DEFAULT_OPTIONS.merge(options)
    games = [] of ProtoGame
    page = 1

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
    loop do
      new_games = get_page(username, options, page)
      page += 1
      games.concat(new_games)
      break if new_games.size != 50
    end

    games
  end

  macro spawn_call(username, options, page, channel, offset)
    proc = -> (page : Int32) do
      spawn do 
        new_games = get_page({{username}}, {{options}}, page + {{offset}})
        {{channel}}.send(new_games)
      end
    end
    proc.call({{page}})
  end

  # 200 is good, 302 means session is expired
  private def self.get_page(username : String, options : Hash(String, String), page : Int32)
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
      parse_html_games(response.body)
    end
  end

  # return a list of proto game objects (id, p1 accurcy, p2 accuarcy)
  private def self.parse_html_games(html : String) : Array(ProtoGame)
    html = Myhtml::Parser.new(html)
    games = html.css(".archive-games-table tbody tr").map { |tr| parse_html_game(tr) }
    games
  end

  private def self.parse_html_game(row) : ProtoGame
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
    ProtoGame.new(id: id, time_class: time_class, link: link.to_s, moves: moves, white: white, black: black)
  end
end

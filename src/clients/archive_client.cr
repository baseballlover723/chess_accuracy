require "http/client"
require "../active_session"

class ArchiveClient
  URL = "https://www.chess.com/games/archive/"

  def self.get_games(username : String, page : Int32 = 1)
    puts "headers: #{ActiveSession.get.headers.inspect}"
    response = HTTP::Client.get(URL + username, headers: ActiveSession.get.headers)
    # puts response.inspect
    puts response.status_code
    # puts response.body
  end
end

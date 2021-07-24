require "./proto_game_color"

struct ProtoGame
  property id : Int64, time_class : String, link : String, moves : UInt16, white : ProtoGameColor, black : ProtoGameColor

  @white_username = ""
  @black_username = ""

  def initialize(@id : Int64, @time_class : String, @link : String, @moves : UInt16, @white : ProtoGameColor, @black : ProtoGameColor)
    @white_username = white.username.downcase
    @black_username = black.username.downcase
  end

  def user(username : String) : ProtoGameColor
    username = username.downcase
    case
    when @white_username == username
      white
    when @black_username == username
      black
    else
      puts "self: #{self.pretty_inspect}"
      raise "user: \"#{username}\" not in game"
    end
  end

  def opponent(username : String) : ProtoGameColor
    username = username.downcase
    case
    when @white_username == username
      black
    when @black_username == username
      white
    else
      puts "self: #{self.pretty_inspect}"
      raise "user: \"#{username}\" not in game"
    end
  end
end

require "./color"

struct ProtoGameColor
  property color : Color, username : String, accuracy : Float64?

  def initialize(@color : Color, @username : String, @accuracy : Float64?)
  end
end

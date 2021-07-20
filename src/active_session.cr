require "./clients/login_client"

class ActiveSession
  @@instance = ActiveSession.new("", "")

  property key : String
  property value : String

  def initialize(@key : String, @value : String)
  end

  def self.set(session : ActiveSession) : ActiveSession
    @@instance = session
  end

  def self.set(key : String, value : String) : ActiveSession
    @@instance = ActiveSession.new(key, value)
  end

  def self.get : ActiveSession
    @@instance
  end

  def headers : HTTP::Headers
    cookies = {key => value}
    HTTP::Headers{"cookie" => cookies.join { |key, value| key + "=" + value + "; " }}
  end
end

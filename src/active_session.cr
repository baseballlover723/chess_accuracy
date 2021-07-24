require "./clients/login_client"

class ActiveSession
  @@instance = ActiveSession.new({} of String => String)

  property headers : Hash(String, String)

  def initialize(@headers : Hash(String, String))
  end

  def initialize(str_headers : String)
    @headers = Hash(String, String).from_json(str_headers)
  end

  def self.set(session : ActiveSession) : ActiveSession
    @@instance = session
  end

  def self.set(headers : Hash(String, String)) : ActiveSession
    @@instance = ActiveSession.new(headers)
  end

  def self.set(str_headers : String) : ActiveSession
    @@instance = ActiveSession.new(str_headers)
  end

  def self.get : ActiveSession
    @@instance
  end

  def headers : HTTP::Headers
    HTTP::Headers{"cookie" => @headers.join { |key, value| key + "=" + value + "; " }}
  end
end

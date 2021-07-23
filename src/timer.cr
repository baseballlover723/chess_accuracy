# TODO move to own library
# TODO handle stopping multiple times
# TODO doesn't handle threadsafe

class Timer
  alias Id = Symbol

  @@timers = Hash(Id, Timer).new { |h, k| h[k] = Timer.new }

  property start : Time::Span, duration : Time::Span, started : Bool

  def initialize
    @start = Time::Span.new
    @duration = Time::Span.new
    @started = false
  end

  macro default_timer
    :default
  end

  def self.start
    start(default_timer)
  end

  def self.start(*ids : Id)
    now = Time.monotonic
    ids.each do |id|
      @@timers[id].start = now
    end
  end

  def self.stop
    stop(default_timer)
  end

  def self.stop(*ids : Id)
    now = Time.monotonic
    ids.each do |id|
      @@timers[id].duration += now - @@timers[id].start
    end
  end

  def self.time
    time(default_timer)
  end

  def self.time(*ids : Id)
    start(*ids)
    result = yield
    stop(*ids)
    result
  end

  def self.exclude
    exclude(default_timer)
  end

  def self.exclude(*ids : Id)
    stop(*ids)
    result = yield
    start(*ids)
    result
  end

  def self.duration
    duration(default_timer)
  end

  def self.duration(id : Id)
    sb = String::Builder.new
    {% begin %}
      {% for unit, abr in {days: "days", hours: "hours", minutes: "mins", seconds: "secs", milliseconds: "ms", microseconds: "us"} %}
        %value = @@timers[id].duration.{{unit.id}}
        {% if unit == "microseconds" %}
          %value %= 1000
        {% end %}
        sb << "#{%value} {{abr.id}}, " if %value > 0
      {% end %}
    sb.back(2)
    {% end %}
    sb.to_s.reverse.sub(" ,", " and ".reverse).reverse
  end

  def self.print
    self.print(default_timer)
  end

  def self.print(*ids : Id)
    ids.each do |id|
      puts "#{id} took #{duration(id)}"
    end
  end

  def self.print_all
    @@timers.keys.each do |id|
      self.print(id)
    end
  end
end

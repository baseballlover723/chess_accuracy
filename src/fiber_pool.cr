class FiberPool(ParamType, ReturnType)
  getter capacity : Int32

  def initialize(@capacity : Int32 = 4)
    @param_channel = Channel({ParamType, (ParamType -> ReturnType), Channel(ReturnType)}).new
    @capacity.times do |i|
      spawn do
        loop do
          param, block, return_channel = @param_channel.receive
          return_channel.send(block.call(param))
        end
      end
    end
  end

  def run(param : ParamType, &block : ParamType -> ReturnType) : ReturnType
    return_channel = Channel(ReturnType).new
    @param_channel.send({param, block, return_channel})
    return_channel.receive
  end
end

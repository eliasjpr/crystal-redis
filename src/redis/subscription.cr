# Models a subscription to one or more channels.
#
# The caller sets callbacks on this object that the Redis client will
# trigger for the appropriate events.
class Subscription
  property :subscribe_callback
  property :psubscribe_callback
  property :message_callback
  property :pmessage_callback
  property :unsubscribe_callback
  property :punsubscribe_callback

  def initialize
    # By default, the callbacks do nothing.
    @subscribe_callback = ->(channel : String, subscriptions : Int64) {}
    @psubscribe_callback = ->(channel_pattern : String, subscriptions : Int64) {}
    @message_callback = ->(channel : String, message : String) {}
    @pmessage_callback = ->(channel_pattern : String, channel : String, message : String) {}
    @unsubscribe_callback = ->(channel : String, subscriptions : Int64) {}
    @punsubscribe_callback = ->(channel_pattern : String, subscriptions : Int64) {}
  end

  # Sets the 'subscribe' callback.
  def subscribe(&block : String, Int64 ->)
    @subscribe_callback = block
  end

  # Sets the 'psubscribe' callback.
  def psubscribe(&block : String, Int64 ->)
    @psubscribe_callback = block
  end

  # Sets the 'message' callback.
  def message(&block : String, String ->)
    @message_callback = block
  end

  # Sets the 'pmessage' callback.
  def pmessage(&block : String, String, String ->)
    @pmessage_callback = block
  end

  # Sets the 'unsubscribe' callback.
  def unsubscribe(&block : String, Int64 ->)
    @unsubscribe_callback = block
  end

  # Sets the 'punsubscribe' callback.
  def punsubscribe(&block : String, Int64 ->)
    @punsubscribe_callback = block
  end
end
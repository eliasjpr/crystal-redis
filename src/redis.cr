# The entry point for the Redis client.
#
# See https://github.com/stefanwille/crystal-redis for documentation.
class Redis
  alias RedisValue = Nil | Int32 | Int64 | String | Array(RedisValue)
  alias Request = Array(RedisValue)

  def initialize(host = "localhost", port = 6379, unixsocket = nil)
    @connection = Connection.new(host, port, unixsocket)
    @strategy = Redis::Strategy::SingleStatement.new(@connection)
  end

  def self.open(host = "localhost", port = 6379, unixsocket = nil)
    redis = Redis.new(host, port, unixsocket)
    begin
      yield(redis)
    ensure
      redis.close
    end
  end

  def ping
    command(["PING"]) as String | Future
  end

  def echo(string)
    command(["ECHO", string.to_s]) as String | Future
  end

  def quit
    command(["QUIT"]) as String | Future
  end

  def auth(password)
    command(["AUTH", password]) as String | Future
  end

  def select(database_number)
    command(["SELECT", database_number.to_s]) as String | Future
  end

  def set(key, value, ex = nil, px = nil, nx = nil, xx = nil)
    q = ["SET", key.to_s, value.to_s]
    q << "EX" << ex.to_s if ex
    q << "PX" << px.to_s if px
    q << "NX" << nx.to_s if nx
    q << "XX" << xx.to_s if xx
    command(q) as String | Future
  end

  def rename(old_key, new_key)
    command(["RENAME", old_key.to_s, new_key.to_s]) as String | Future
  end

  def renamenx(old_key, new_key)
    command(["RENAMENX", old_key.to_s, new_key.to_s]) as Int64 | Future
  end

  def get(key)
    command(["GET", key.to_s]) as RedisValue | Future
  end

  def del(*keys)
    command(concat(["DEL"], keys)) as RedisValue | Future
  end

  def sort(key, by = nil, limit = nil, get = nil : Array(RedisValue)?, order = "ASC", alpha = nil : Boolean?, store = nil)
    q = ["SORT", key.to_s]

    if by
      q << "BY" << by.to_s
    end

    if limit
      if limit.length != 2
        raise Error.new("limit must be an array of 2 elements (offset, count)")
      end
      offset, count = limit
      q << "LIMIT" << offset.to_s << count.to_s
    end

    if get
      get.each { |pattern| q << "GET" << pattern }
    end

    if order
      _order = order.upcase
      unless ["ASC", "DESC"].includes?(_order)
        raise Error.new("Bad order #{order}")
      end
      q << _order
    end

    if alpha
      q << "ALPHA"
    end

    if store
      q << "STORE" << store.to_s
    end

    command(q) as Array(RedisValue) | Int64 | Future
  end

  def mget(*keys)
    command(concat(["MGET"] of RedisValue, keys)) as RedisValue | Future
  end

  def mset(hash)
    q = ["MSET"] of RedisValue
    hash.each { |key, value| q << key.to_s << value.to_s }
    command(q) as RedisValue | Future
  end

  def getset(key, value)
    command(["GETSET", key.to_s, value]) as RedisValue | Future
  end

  def setex(key, value, expire_in_seconds)
    command(["SETEX", key.to_s, expire_in_seconds.to_s, value.to_s]) as String | Future
  end

  def psetex(key, value, expire_in_milis)
    command(["PSETEX", key.to_s, expire_in_milis.to_s, value.to_s]) as String | Future
  end

  def setnx(key, value)
    command(["SETNX", key.to_s, value.to_s]) as Int64 | Future
  end

  def msetnx(hash)
    q = ["MSETNX"] of RedisValue
    hash.each { |key, value| q << key.to_s << value }
    command(q) as Int64 | Future
  end

  def incr(key)
    command(["INCR", key.to_s]) as Int64 | Future
  end

  def decr(key)
    command(["DECR", key.to_s]) as Int64 | Future
  end

  def incrby(key, value)
    command(["INCRBY", key.to_s, value.to_s]) as Int64 | Future
  end

  def incrbyfloat(key, value)
    command(["INCRBYFLOAT", key.to_s, value.to_s]) as String | Future
  end

  def decrby(key, value)
    command(["DECRBY", key.to_s, value.to_s]) as Int64 | Future
  end

  def append(key, value)
    command(["APPEND", key.to_s, value.to_s]) as Int64 | Future
  end

  def strlen(key)
    command(["STRLEN", key.to_s]) as Int64 | Future
  end

  def getrange(key, start_index, end_index)
    command(["GETRANGE", key.to_s, start_index.to_s, end_index.to_s]) as String | Future
  end

  def setrange(key, start_index, s)
    command(["SETRANGE", key.to_s, start_index.to_s, s.to_s]) as Int64 | Future
  end

  def bitcount(key, from, to)
    command(["BITCOUNT", key.to_s, from.to_s, to.to_s]) as Int64 | Future
  end

  def bitop(operation, key, *keys)
    q = ["BITOP", operation.to_s, key.to_s] of RedisValue
    keys.each { |key| q << key.to_s }
    command(q)
  end

  def getbit(key, index)
    command(["GETBIT", key.to_s, index.to_s]) as Int64 | Future
  end

  def setbit(key, index, value)
    command(["SETBIT", key.to_s, index.to_s, value.to_s]) as Int64 | Future
  end

  def bitpos(key, bit, start = nil, to = nil)
    q = ["BITPOS", key.to_s, bit.to_s] of RedisValue
    if start
      q << start.to_s
      if to
        q << to
      end
    end
    command(q)
  end

  def dump(key)
    command(["DUMP", key.to_s]) as String | Future
  end

  def restore(key, ttl_in_milis : Int, serialized_value : String | Redis::Future)
    if serialized_value.is_a?(Redis::Future)
      raise "Can't use a Future for serialized_value"
    end
    replace = nil
    q = ["RESTORE", key.to_s, ttl_in_milis.to_s, serialized_value] of RedisValue
    if replace
      q << replace.to_s
    end
    command(q) as String | Future
  end

  def scan(cursor, match = nil, count = nil)
    q = ["SCAN", cursor.to_s]
    if match
      q << match
      if count
        q << count
      end
    end
    result = command(q)
    # Keep the compiler happy.
    unless result
      "Redis: Missing result"
    end
    result as Array(RedisValue) | Future
  end

  def randomkey
    command(["RANDOMKEY"]) as String | Future
  end

  def exists(key)
    command(["EXISTS", key.to_s]) as Int64 | Future
  end

  def keys(pattern)
    command(["KEYS", pattern.to_s]) as Array(RedisValue) | Future
  end

  def rpush(key, *values)
    q = ["RPUSH", key.to_s]
    values.each { |value| q << value.to_s }
    command(q) as Int64 | Future
  end

  def lpush(key, *values)
    q = ["LPUSH", key.to_s]
    values.each { |value| q << value.to_s }
    command(q) as Int64 | Future
  end

  def lpushx(key, value)
    command(["LPUSHX", key.to_s, value.to_s]) as Int64 | Future
  end

  def rpushx(key, value)
    command(["RPUSHX", key.to_s, value.to_s]) as Int64 | Future
  end

  def lrem(key, count, value)
    command(["LREM", key.to_s, count.to_s, value.to_s]) as Int64 | Future
  end

  def llen(key)
    command(["LLEN", key.to_s]) as Int64 | Future
  end

  def lindex(key, index)
    command(["LINDEX", key.to_s, index.to_s]) as String? | Future
  end

  def lset(key, index, value)
    command(["LSET", key.to_s, index.to_s, value.to_s]) as String | Future
  end

  def lpop(key)
    command(["LPOP", key.to_s]) as String? | Future
  end

  def rpop(key)
    command(["RPOP", key.to_s]) as String? | Future
  end

  def linsert(key, where, pivot, value)
    command(["LINSERT", key.to_s, where.to_s, pivot.to_s, value.to_s]) as Int64 | Future
  end

  def lrange(key, from, to)
    command(["LRANGE", key.to_s, from.to_s, to.to_s]) as Array(RedisValue) | Future
  end

  def ltrim(key, start, stop)
    command(["LTRIM", key.to_s, start.to_s, stop.to_s]) as RedisValue | Future
  end

  def sadd(key, *values)
    q = ["SADD", key.to_s]
    values.each { |value| q << value.to_s }
    command(q) as Int64 | Future
  end

  def smembers(key)
    command(["SMEMBERS", key.to_s]) as Array(RedisValue) | Future
  end

  def sismember(key, value)
    command(["SISMEMBER", key.to_s, value.to_s]) as Int64 | Future
  end

  def srem(key, *values)
    q = ["SREM", key.to_s]
    values.each { |value| q << value.to_s }
    command(q) as Int64 | Future
  end

  def scard(key)
    command(["SCARD", key.to_s]) as Int64 | Future
  end

  def sdiff(*keys)
    q = ["SDIFF"]
    keys.each { |key| q << key.to_s }
    command(q) as Array(RedisValue) | Future
  end

  def sdiffstore(destination_key, *keys)
    q = ["SDIFFSTORE", destination_key.to_s]
    keys.each { |key| q << key.to_s }
    command(q) as Int64 | Future
  end

  def sinter(*keys)
    q = ["SINTER"]
    keys.each { |key| q << key.to_s }
    command(q) as Array(RedisValue) | Future
  end

  def sinterstore(destination_key, *keys)
    q = ["SINTERSTORE", destination_key.to_s]
    keys.each { |key| q << key.to_s }
    command(q) as Int64 | Future
  end

  def smove(source, destination, member)
    command(["SMOVE", source.to_s, destination.to_s, member.to_s]) as Int64 | Future
  end

  def spop(key, count = nil)
    q = ["SPOP", key.to_s]
    # Redis 3.0 should have the "count" argument, but doesn't yet.
    if count
      q << count.to_s
    end
    command(q) as String | Array(RedisValue) | Future
  end

  def srandmember(key, count)
    command(["SRANDMEMBER", key.to_s, count.to_s]) as Array(RedisValue) | Future
  end

  def sscan(key, cursor, match = nil, count = nil)
        q = ["SSCAN", key.to_s, cursor.to_s]
    if match
      q << match
      if count
        q << count
      end
    end
    result = command(q)
    # Keep the compiler happy.
    unless result
      "Redis: Missing result"
    end
    result as Array(RedisValue) | Future
  end

  def sunion(*keys)
    q = ["SUNION"]
    keys.each { |key| q << key.to_s }
    command(q) as Array(RedisValue) | Future
  end

  def sunionstore(destination_key, *keys)
    q = ["SUNIONSTORE", destination_key.to_s]
    keys.each { |key| q << key.to_s }
    command(q) as Int64 | Future
  end

  def blpop(keys, timeout_in_seconds)
    q = ["BLPOP"]
    keys.each { |key| q << key.to_s }
    q << timeout_in_seconds.to_s
    command(q) as Array(RedisValue)? | Future
  end

  def brpop(keys, timeout_in_seconds)
    q = ["BRPOP"]
    keys.each { |key| q << key.to_s }
    q << timeout_in_seconds.to_s
    command(q) as Array(RedisValue)? | Future
  end

  def rpoplpush(source, destination)
    command(["RPOPLPUSH", source.to_s, destination.to_s]) as RedisValue | Future
  end

  def brpoplpush(source, destination, timeout_in_seconds)
    command(["BRPOPLPUSH", source.to_s, destination.to_s, timeout_in_seconds.to_s]) as RedisValue | Future
  end

  def hset(key, field, value)
    command(["HSET", key.to_s, field.to_s, value.to_s]) as RedisValue | Future
  end

  def hget(key, field)
    command(["HGET", key.to_s, field.to_s]) as String? | Future
  end

  def hgetall(key)
    result = command(["HGETALL", key.to_s]) as Array(RedisValue) | Future
  end

  def hdel(key, field)
    command(["HDEL", key.to_s, field.to_s]) as Int64 | Future
  end

  def hexists(key, field)
    command(["HEXISTS", key.to_s, field.to_s]) as Int64 | Future
  end

  def hincrby(key, field, delta)
    command(["HINCRBY", key.to_s, field.to_s, delta.to_s]) as Int64 | Future
  end

  def hincrbyfloat(key, field, delta)
    command(["HINCRBYFLOAT", key.to_s, field.to_s, delta.to_s]) as String | Future
  end

  def hkeys(key)
    command(["HKEYS", key.to_s]) as Array(RedisValue) | Future
  end

  def hlen(key)
    command(["HLEN", key.to_s]) as Int64 | Future
  end

  def hmget(key, *fields)
    q = ["HMGET", key.to_s] of RedisValue
    fields.each { |field| q << field.to_s }
    command(q) as Array(RedisValue) | Future
  end

  def hmset(key, hash)
    q = ["HMSET", key.to_s] of RedisValue
    hash.each { |field, value| q << field.to_s << value }
    command(q) as String | Future
  end

  def hscan(key, cursor, match = nil, count = nil)
        q = ["HSCAN", key.to_s, cursor.to_s]
    if match
      q << match
      if count
        q << count
      end
    end
    result = command(q)
    # Keep the compiler happy.
    unless result
      "Redis: Missing result"
    end
    result as Array(RedisValue) | Future
  end

  def hsetnx(key, field, value)
    command(["HSETNX", key.to_s, field.to_s, value.to_s]) as Int64 | Future
  end

  def hvals(key)
    command(["HVALS", key.to_s]) as Array(RedisValue) | Future
  end

  def zadd(key, *scores_and_members)
    q = ["ZADD", key.to_s]
    if scores_and_members.length % 2 > 0
      raise Error.new("zadd expects an array of scores mapped to members")
    end
    count = scores_and_members.length / 2
    index = 0
    count.times do
      score = scores_and_members[index].to_s
      member = scores_and_members[index + 1].to_s
      q << score << member
      index += 2
    end
    command(q) as Int64 | Future
  end

  def zrange(key, start = nil, stop = nil, with_scores = false)
    q = ["ZRANGE", key.to_s, start.to_s, stop.to_s]
    if with_scores
      q << "WITHSCORES"
    end
    command(q) as Array(RedisValue) | Future
  end

  def zcard(key)
    command(["ZCARD", key.to_s]) as Int64 | Future
  end

  def zscore(key, member)
    command(["ZSCORE", key.to_s, member.to_s]) as String? | Future
  end

  def zcount(key, min, max)
    command(["ZCOUNT", key.to_s, min.to_s, max.to_s]) as Int64 | Future
  end

  def zlexcount(key, min, max)
    command(["ZLEXCOUNT", key.to_s, min.to_s, max.to_s]) as Int64 | Future
  end

  def zincrby(key, increment, member)
    command(["ZINCRBY", key.to_s, increment.to_s, member.to_s]) as String | Future
  end

  def zrem(key, member)
    command(["ZREM", key.to_s, member.to_s]) as Int64 | Future
  end

  def zrank(key, member)
    command(["ZRANK", key.to_s, member.to_s]) as Int64? | Future
  end

  def zrevrank(key, member)
    command(["ZREVRANK", key.to_s, member.to_s]) as Int64? | Future
  end

  def zinterstore(destination, keys : Array, weights = nil, aggregate = nil)
    numkeys = keys.length
    q = ["ZINTERSTORE", destination.to_s, numkeys.to_s]
    keys.each { |keys| q << keys.to_s }
    if weights
      q << "WEIGHTS"
      weights.each { |weight| q << weight.to_s }
    end
    if aggregate
      q << "AGGREGATE" << aggregate.to_s
    end
    command(q) as Int64 | Future
  end

  def zunionstore(destination, keys : Array, weights = nil, aggregate = nil)
    numkeys = keys.length
    q = ["ZUNIONSTORE", destination.to_s, numkeys.to_s]
    keys.each { |keys| q << keys.to_s }
    if weights
      q << "WEIGHTS"
      weights.each { |weight| q << weight.to_s }
    end
    if aggregate
      q << "AGGREGATE" << aggregate.to_s
    end
    command(q) as Int64 | Future
  end

  def zrangebylex(key, min, max, limit = nil)
    q = ["ZRANGEBYLEX", key.to_s, min.to_s, max.to_s]
    if limit
      q << "LIMIT" << limit[0].to_s << limit[1].to_s
    end
    command(q) as Array(RedisValue) | Future
  end

  def zrangebyscore(key, min, max, limit = nil, with_scores = false)
    q = ["ZRANGEBYSCORE", key.to_s, min.to_s, max.to_s]
    if limit
      q << "LIMIT" << limit[0].to_s << limit[1].to_s
    end
    if with_scores
      q << "WITHSCORES"
    end
    command(q) as Array(RedisValue) | Future
  end

  def zrevrange(key, start, stop, with_scores = false)
    q = ["ZREVRANGE", key.to_s, start.to_s, stop.to_s]
    if with_scores
      q << "WITHSCORES"
    end

    command(q) as Array(RedisValue) | Future
  end

  def zrevrangebylex(key, min, max, limit = nil)
    q = ["ZREVRANGEBYLEX", key.to_s, min.to_s, max.to_s]
    if limit
      q << "LIMIT" << limit[0].to_s << limit[1].to_s
    end
    command(q) as Array(RedisValue) | Future
  end

  def zrevrangebyscore(key, min, max, limit = nil, with_scores = false)
    q = ["ZREVRANGEBYSCORE", key.to_s, min.to_s, max.to_s]
    if limit
      q << "LIMIT" << limit[0].to_s << limit[1].to_s
    end
    if with_scores
      q << "WITHSCORES"
    end
    command(q) as Array(RedisValue) | Future
  end

  def zremrangebylex(key, min, max)
    command(["ZREMRANGEBYLEX", key.to_s, min.to_s, max.to_s]) as Int64 | Future
  end

  def zremrangebyrank(key, start, stop)
    command(["ZREMRANGEBYRANK", key.to_s, start.to_s, stop.to_s]) as Int64 | Future
  end

  def zremrangebyscore(key, start, stop)
    command(["ZREMRANGEBYSCORE", key.to_s, start.to_s, stop.to_s]) as Int64 | Future
  end

  def zscan(key, cursor, match = nil, count = nil)
        q = ["ZSCAN", key.to_s, cursor.to_s]
    if match
      q << match
      if count
        q << count
      end
    end
    result = command(q)
    # Keep the compiler happy.
    unless result
      "Redis: Missing result"
    end
    result as Array(RedisValue) | Future
  end

  def pfadd(key, *values)
    q = ["PFADD", key.to_s]
    values.each { |value| q << value.to_s }
    command(q) as Int64 | Future
  end

  def pfmerge(*keys)
    q = ["PFMERGE"]
    keys.each { |key| q << key.to_s }
    command(q) as String | Future
  end

  def pfcount(key)
    command(["PFCOUNT", key.to_s]) as Int64 | Future
  end

  def eval(script : String, keys = [] of RedisValue, args = [] of RedisValue)
    q = ["EVAL", script, keys.length.to_s] of RedisValue
    q.concat(keys)
    q.concat(args)
    command(q) as Array(RedisValue) | Future
  end

  def evalsha(sha1, keys = [] of RedisValue, args = [] of RedisValue)
    unless sha1.is_a?(String)
      raise "Redis: Call evalsha with a String, not a #{sha1.class}"
    end
    q = ["EVALSHA", sha1, keys.length.to_s] of RedisValue
    q.concat(keys)
    q.concat(args)
    command(q) as Array(RedisValue) | Future
  end

  def script_load(script : String)
    command(["SCRIPT", "LOAD", script]) as String | Future
  end

  def script_kill
    command(["SCRIPT", "KILL"]) as String | Future
  end

  def script_exists(sha1_array : Array(Reference))
    q = ["SCRIPT", "EXISTS"] of RedisValue
    sha1_array.each do |sha1|
      q << (sha1 as String)
    end
    command(q)
  end

  def script_flush
    command(["SCRIPT", "FLUSH"]) as String | Future
  end

  def expire(key, seconds)
    command(["EXPIRE", key.to_s, seconds.to_s]) as Int64 | Future
  end

  def pexpire(key, milis)
    command(["PEXPIRE", key.to_s, milis.to_s]) as Int64 | Future
  end

  def expireat(key, unix_date)
    command(["EXPIREAT", key.to_s, unix_date.to_s]) as Int64 | Future
  end

  def pexpireat(key, unix_date_in_milis)
    command(["PEXPIREAT", key.to_s, unix_date_in_milis.to_s]) as Int64 | Future
  end

  def persist(key)
    command(["PERSIST", key.to_s]) as Int64 | Future
  end

  def ttl(key)
    command(["TTL", key.to_s]) as Int64 | Future
  end

  def pttl(key)
    command(["PTTL", key.to_s]) as Int64 | Future
  end

  def type(key)
    command(["TYPE", key.to_s]) as String | Future
  end

  def subscribe(*channels, &callback_setup_block : Subscription ->)
    subscription = Subscription.new
    # Allow the caller to populate the subscription with his callbacks.
    callback_setup_block.call(subscription)

    @strategy = Redis::Strategy::SubscriptionLoop.new(@connection, subscription)

    subscribe(*channels)
  end

  def subscribe(*channels)
    unless already_in_subscription_loop?
      raise Redis::Error.new("Must call subscribe with a block")
    end

    q = ["SUBSCRIBE"] of RedisValue
    channels.each { |channel| q << channel.to_s }
    command(q)
  end

  def psubscribe(*channel_patterns, &callback_setup_block : Subscription ->)
    subscription = Subscription.new
    # Allow the caller to populate the subscription with his callbacks.
    callback_setup_block.call(subscription)

    @strategy = Redis::Strategy::SubscriptionLoop.new(@connection, subscription)

    psubscribe(*channel_patterns)
  end

  def psubscribe(*channel_patterns)
    unless already_in_subscription_loop?
      raise Redis::Error.new("Must call psubscribe with a block")
    end

    q = ["PSUBSCRIBE"] of RedisValue
    channel_patterns.each { |channel_pattern| q << channel_pattern.to_s }
    command(q)
  end

  private def already_in_subscription_loop?
    @strategy.is_a? Redis::Strategy::SubscriptionLoop
  end

  def unsubscribe(*channels)
    q = ["UNSUBSCRIBE"] of RedisValue
    channels.each { |channel| q << channel.to_s }
    command(q)
  end

  def punsubscribe(*channel_patterns)
    q = ["PUNSUBSCRIBE"] of RedisValue
    channel_patterns.each { |channel_pattern| q << channel_pattern.to_s }
    command(q)
  end

  def publish(channel, message)
    command(["PUBLISH", channel.to_s, message.to_s]) as Int64 | Future
  end

  def discard
    @strategy.discard
  end

  def pipelined
    @strategy = Redis::Strategy::Pipeline.new(@connection)
    @strategy.begin
    yield
    @strategy.commit as Array(RedisValue)
  ensure
    @strategy = Redis::Strategy::SingleStatement.new(@connection)
  end

  def transaction
    @strategy = Redis::Strategy::Transaction.new(@connection)
    @strategy.begin
    yield(self)
    @strategy.commit as Array(RedisValue)
  ensure
    @strategy = Redis::Strategy::SingleStatement.new(@connection)
  end

  def command(request : Array(RedisValue))
    @strategy.command(request) as RedisValue | Future
  end

  def close
    @connection.close
  end

  private def concat(destination : Array(RedisValue), source)
    source.each { |value| destination << value.to_s }
    destination
  end
end

require "./**"

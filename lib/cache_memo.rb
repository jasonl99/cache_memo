module CacheMemo

  class CacheData < SimpleDelegator

    FUTURE = '3000-Jan-15'.to_datetime
    RESERVED_KEYS = [:next_gc, :reads, :writes]
    require 'digest/sha1'

    class ArgumentError < StandardError
    end

    def initialize(init={})
      raise ArgumentError, "The initial value must be a hash." unless init.is_a? Hash
      super init
      self[:__global_gc__] = DateTime.now + 1000.years
    end


    # Cleans out expired data for a particular method. 
    # Each method has a :next_gc key, which represents the next time
    # a cached value will expire for this method across all parameter signatures.  for example:
    # {
    #   some_method: {
    #     next_gc: 22 Jan 15 3:45PM
    #     [100,'Bob']: {expires:..., value:...},
    #     [100,'Jim']: {expires:..., value:...}
    #
    # This means that one of Bob or Jim (or both) expire at 3:45pm.  Basically, at 3:45pm, this
    # method needs to be garbage collected.  This next_gc is used the master :__global_gc__
    # Each time #set is called, it clears cached parameter signature for any that are expired.
    # Regardless, it updates the next time garbage collection would be required for this method
    # so it can *still* be cleared out with a global clearing method.
    def garbage_collect(method:)
      oldest = self[method][:next_gc]
      self[method].except(*RESERVED_KEYS).each do |key, value|
        oldest = [value[:expires],oldest].min if value[:expires] > DateTime.now # save now, because it'll get deleted
        self[method].delete(key) if value[:expires] <= DateTime.now
        self[method][:next_gc] = cache_empty?(method) ? oldest : FUTURE
      end
      self[method][:next_gc]
    end

    def cache_empty?(method)
      self[method].except(*RESERVED_KEYS).keys.any?
    end

    def full_garbage_collect(expiration: FUTURE)
      # new_expiration is a newly cached value.
      self[:__global_gc__] = expiration if expiration < self[:__global_gc__]
      if self[:__global_gc__] < DateTime.now
        self[:__global_gc__] = FUTURE # sets the next far into future; will adjust as each method is collected
        self.except(:__global_gc__).keys.each do |method|
          self[method][:next_gc] = garbage_collect(method:method)
          self[:__global_gc__] = [self[:__global_gc__],self[method][:next_gc]].min
        end.compact
      end
    end

    # sets the value in the hash.  The hash takes the form
    # method_name => {args_signature => {expires: ..., value: ...}
    def set(name:, value:, expires:, args_signature: )
      self[name] = {next_gc: expires, reads:0, writes: 0} if self[name].nil?
      self[name].merge! args_signature=> {value: value, expires: expires}
      self[name][args_signature][:value]
    end

    # args are passed in from the instance's #cache_for, which we define below.
    # This is simply an array of arguments that are not processed; they are used
    # by cache_for block and we have no knowledge of what they mean.  However,
    # they are useful because we can create a signature from them.  Before generating
    # the signature, create a string from the array.  If the string is less than
    # 100 characters (a *completely* arbitrary number), we simply use the array as the
    # hash key, otherwise we generate a SHA1 digest of the string.  This serves two
    # useful purposes:  1) for cases with simple variable (ints, strings, etc) we
    # don't have to go through the process of creating a SHA1 hash.  Second,
    # we can much more easily inspect the cache data for debugging purposes, etc.
    def signature(args)
      str = args.to_s
      if str.length <=100
        args
      else
        Digest::SHA1.hexdigest args.to_s
      end
    end

    def update_method_stats(method:, expiration:)
      # garbage collects and creates statistics
      # (no stats yet though)
      self[method][:next_gc] = expiration if expiration < self[method][:next_gc]
      # if self[method][:next_gc] < DateTime.now  # do garbage collection now
      #   self[method][:next_gc] = garbage_collect method: method
      # else  #otherwise, take the smaller of the existing or new
      #   self[method][:next_gc] = [self[method][:next_gc], expiration].min
      # end
    end

    # The memoized value is considered expired if either it doesn't exist or the expiration
    # date has pased.
    def expired?(name:, expires:, args_signature: )
      self.fetch(name,{})[args_signature].nil? || self[name][args_signature][:expires] < DateTime.now
    end

    # this is the method called by the module's main method, #cache_for().
    # args are simply absorbed into an array in cache_for and passed into this method.
    def value(name, expires, args)
      raise CacheData::ArgumentError, "parameter :expires must be a duration (5.seconds, 2.minutes)" unless expires.is_a? ActiveSupport::Duration
      args_signature = signature(args)
      if expired?(name: name, expires: expires, args_signature: args_signature)
        set name: name, value: yield(*args), expires: DateTime.now + expires, args_signature: args_signature
        update_method_stats method: name, expiration: DateTime.now + expires
        self[name][:writes] += 1
      else
        self[name][args_signature][:value]
        self[name][:reads] += 1
      end
      full_garbage_collect(expiration: DateTime.now + expires)
    end

  end

  def cache_data
    @cache_memo_data
  end

  # this is the method that will get used by the class to do the work.  An example call might look like this:
  #
  # def country_gdp(country)
  #   cache_for(1.day,country)
  #     calculate_country_gdp(country) # presumably this is an expensive transaction
  #   end
  # end
  def cache_for(expires, *args, &blk)
    @cache_memo_data ||= CacheData.new
    @cache_memo_data.value caller_locations(1,1)[0].label.to_sym, expires, args, &blk
  end

end


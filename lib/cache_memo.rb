module CacheMemo

  class CacheData

    FUTURE = '3000-Jan-15'.to_datetime
    RESERVED_KEYS = [:next_gc, :reads, :writes]
    require 'digest/sha1'

    class ArgumentError < StandardError
    end

    def initialize
      @cache_data = Hash.new {|h,k| h[k] = RESERVED_KEYS.include?(k)? nil : Hash.new(&h.default_proc)}
      @method_expirations = {}  # keeps track of when the next cached object expires for this method
    end

    def cache_data
      @cache_data
    end

    def method_expirations
      @method_expirations
    end

    def signatures(method)
      method_cache(method).keys
    end

    def method_cache(method)
      cache_data(method).except(*RESERVED_KEYS)
    end

    def remove_method_signature(method,signature)
      cache_data[method].delete signature
    end

    # def next_expiration(method, expiration=:_get_)
    #   if expiration == :_get_
    #     @method_expirations[method]
    #   else
    #     @method_expirations[method] = cache_empty?(method) ? expiration : FUTURE
    #   end
    # end

    def signature_expiration(method, signature, expiration = :_get_)
      if expiration == :_get_
        [method,signature,:expires].inject(cache_data,:fetch) rescue nil
      else
        [method,signature].inject(cache_data,:fetch)[:expires] = expiration
      end
    end

    def method_expiration(method, expiration=:_get_)
      if expiration == :_get_
        method_expirations[method]
      else
        method_expirations[method] = expiration
      end
    end

    def garbage_collect(method:)
      current_expiration = next_expiration(method)
      signatures(method).each do |signature|
        if next_expires > DateTime.now
          current_expiration = [current_expiration, signature_expiration(method,signature)].min
          next_expiration(method,current_expiration)
        else
          remove_signature(method,signature)
        end
      end
      next_expiration(method)
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

    def get_method_cache(method)
      @cache_data[method] ||= {reads: 0, writes: 0}
    end

    def signature_value(method,signature,value=:_get_)
      if value == :_get_
        [method,signature,:value].inject(cache_data,:fetch)
      else
        [method,signature].inject(cache_data,:fetch)[:value] = value
      end
    end

    def set(method:, value:, expires:, args_signature: )
      cache = get_method_cache(method)
      cache.merge! args_signature=> {value: value, expires: expires}
      signature_value(method,args_signature)
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

    def update_method_stats(method, data)
      cache_data[method].merge! data.slice(*RESERVED_KEYS)
    end

    def method_writes(method)
      cache_data[method][:writes] || 0
    end

    def method_reads(method)
      cache_data[method][:reads] || 0
    end

    # The memoized value is considered expired if either it doesn't exist or the expiration
    # date has pased.
    def expired?(method:, signature: )
      dt = DateTime.now
      (signature_expiration(method, signature) || dt) <= dt
    end

    # this is the method called by the module's main method, #cache_for().
    # args are simply absorbed into an array in cache_for and passed into this method.
    def value(name, expires, args)
      raise CacheData::ArgumentError, "parameter :expires must be a duration (5.seconds, 2.minutes)" unless expires.is_a? ActiveSupport::Duration
      args_signature = signature(args)
      if expired?(method: name, signature: args_signature)
        set method: name, value: yield(*args), expires: DateTime.now + expires, args_signature: args_signature
        update_method_stats name, expiration: DateTime.now + expires,  writes: method_writes(name) + 1
        #FIXME: self[name][:writes] += 1
      else
        update_method_stats name, reads: method_reads(name) + 1
        signature_value(name,args_signature)
      end
      # FIXME: full_garbage_collect(expiration: DateTime.now + expires)
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


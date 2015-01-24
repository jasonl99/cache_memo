module CacheMemo

  class CacheData

    FUTURE = '3000-Jan-15'.to_datetime
    RESERVED_KEYS = [:next_gc, :reads, :writes, :_get_]
    SHA1_THRESHHOLD = 100

    require 'digest/sha1'

    class ArgumentError < StandardError
    end

    def initialize
      # auto-vivifying hash except reserved keys which are set to nil.
      @cache_data = Hash.new {|h,k| h[k] = RESERVED_KEYS.include?(k)? nil : Hash.new(&h.default_proc)}
      @method_expirations = {}  # keeps track of when the next cached object expires for this method
    end

    def cache_data
      @cache_data
    end

    # simple hash to store method expirations in the form {method_name: expiration_date}
    def method_expirations
      @method_expirations
    end

    def expired_methods
      method_expirations.map {|k,v| k if v.past?}.compact
    end

    # Each signature key is based created by #signature.
    def signatures(method)
      method_cache(method).keys
    end

    # Just the hash of signatures for the given method (doesn't return statistical keys)
    def method_cache(method)
      cache_data[method].except(*RESERVED_KEYS)
    end

    # removes a particular signature from a method's cache
    def remove_method_signature(method,signature)
      cache_data[method].delete signature
      method_expiration(method, FUTURE) if cache_empty?(method)
    end

    # maybe unusual for ruby; this is javascript style (one parameter is a getter, two is a setter)
    def method_expiration(method, expiration=:_get_)
      if expiration == :_get_
        method_expirations[method]
      else
        method_expirations[method] = expiration
      end
    end

    def signature_expiration(method, signature, expiration = :_get_)
      if expiration == :_get_
        method_expiration(method, expiration)
        [method,signature,:expires].inject(cache_data,:fetch) rescue nil
      else
        [method,signature].inject(cache_data,:fetch)[:expires] = expiration
      end
    end

    # removes values for expired parameter signatures
    def garbage_collect(method:)
      current_expiration = method_expiration(method)
      signatures(method).each do |signature|
        if current_expiration > DateTime.now
          current_expiration = [current_expiration, signature_expiration(method,signature)].min
          method_expiration(method,current_expiration)
        else
          remove_method_signature(method,signature)
        end
      end
      method_expiration(method)
    end

    def cache_empty?(method)
      method_cache(method).keys.any?
    end

    # go through expired methods and garbage collect each one
    def full_garbage_collect
      expired_methods.each {|method| garbage_collect method: method}
    end

    # gets the method cache, but adds statistical keys if not yet present
    def get_method_cache(method)
      mc = cache_data[method]
      mc.merge! reads: 0, writes:0 if mc.empty?
      mc
    end

    # grabs the value for a method & signature, or sets it if value is passed
    def signature_value(method,signature,value=:_get_)
      if value == :_get_
        # if expired, it'll return nil
        [method,signature,:value].inject(cache_data,:fetch) if signature_expiration(method, signature) > DateTime.now
      else
        [method,signature].inject(cache_data,:fetch)[:value] = value
      end
    end

    # sets the value and expiration for a given method and signature
    def set(method:, value:, expires:, args_signature: )
      cache = get_method_cache(method)
      cache.merge! args_signature=> {value: value, expires: expires}
      method_expiration method, expires
      signature_value(method,args_signature)
    end

    # args are passed in from the instance's #cache_for, which we define below.
    # This is simply an array of arguments that are not processed; they are used
    # by cache_for block and we have no knowledge of what they mean.  However,
    # they are useful because we can create a signature from them.  Before generating
    # the signature, create a string from the array.  If the string is less than
    # 100 characters (a *completely* arbitrary number), we simply use the array as the
    # signature, otherwise we generate a SHA1 digest of the string.  This serves two
    # useful purposes:  1) for cases with simple variable (ints, strings, etc) we
    # don't have to go through the process of creating a SHA1 hash.  Second,
    # we can much more easily inspect the cache data for debugging purposes, etc.
    def signature(args)
      str = args.to_s
      if str.length <= SHA1_THRESHHOLD
        args
      else
        Digest::SHA1.hexdigest args.to_s
      end
    end

    def update_method_stats(method, data)
      cache_data[method].merge! data
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
      (signature_expiration(method, signature) || DateTeime.now) <= DateTime.now
    end

    # this is the method called by the module's main method, #cache_for().
    # args are simply absorbed into an array in cache_for and passed into this method.
    def value(method, expires, args)
      raise CacheData::ArgumentError, "parameter :expires must be a duration (5.seconds, 2.minutes)" unless expires.is_a? ActiveSupport::Duration
      args_signature = signature(args)
      full_garbage_collect
      if expired?(method: method, signature: args_signature)
        update_method_stats method, writes: method_writes(method) + 1
        method_expiration method, DateTime.now + expires
        set method: method, value: yield(*args), expires: DateTime.now + expires, args_signature: args_signature
      else
        update_method_stats method, reads: method_reads(method) + 1
        signature_value(method,args_signature)
      end
    end

  end

  def cache_data
    @cache_data
  end

  # this is the method that will get used by the class to do the work.  An example call might look like this:
  #
  # def country_gdp(country)
  #   cache_for(1.day,country)
  #     calculate_country_gdp(country) # presumably this is an expensive transaction
  #   end
  # end
  def cache_for(expires, *args, &blk)
    @cache_data ||= CacheData.new
    @cache_data.value caller_locations(1,1)[0].label.to_sym, expires, args, &blk
  end

end


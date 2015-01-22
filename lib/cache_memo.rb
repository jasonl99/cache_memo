module CacheMemo

  class CacheData < SimpleDelegator

    require 'digest/sha1'

    class ArgumentError < StandardError
    end

    def initialize(init={})
      raise ArgumentError, "The initial value must be a hash." unless init.is_a? Hash
      super init
    end


    # sets the value in the hash.  The hash takes the form
    # method_name => {args_signature => {expires: ..., value: ...}
    def set(name:, value:, expires:, args_signature: )
      self[name] = {} if self[name].nil?
      self[name].merge! args_signature=> {value: value, expires: expires}
      self[name][args_signature][:value]
    end

    # The args are converted to a string, from which an SHA1 hash is calculated.
    # Each set of args will produce a different signature.  it is possible that
    # two different sets of arguments will produce the same hash, but this is  so
    # unlikely that it's not to be with it.  The way to fix this would be to calculate
    # an extra signature that gets append to the first with the args + salt like this:
    # Digest::SHA1.hexdigest args.to_s + "this is a salt"
    def signature(args)
      Digest::SHA1.hexdigest args.to_s
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
      else
        self[name][args_signature][:value]
      end
    end

  end

  def cache_data
    @cache_memo_data
  end

  # this is the method that will get used by the class to do the work.  An example call might look like this:
  #
  # def country_gdp(country)
  #   cache_for(1.day) do |country|
  #     calculate_country_gdp(country) # presumably this is an expensive transaction
  #   end
  # end
  def cache_for(expires, *args, &blk)
    @cache_memo_data ||= CacheData.new
    @cache_memo_data.value caller_locations(1,1)[0].label.to_sym, expires, args, &blk
  end

end


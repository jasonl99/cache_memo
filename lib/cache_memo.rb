module CacheMemo


  class CacheData < Hash

    class ArgumentError < StandardError
    end

    def set(name:, value:, expires: )
      self[name] = {value: value, expires: expires}
      self[name][:value]
    end

    def expired?(name:, expires:)
      self[name][:expires].nil? || self[name][:expires] < DateTime.now
    end

    def value(name, expires)
      raise CacheData::ArgumentError, "parameter :expires must be a duration (5.seconds, 2.minutes)" unless expires.is_a? ActiveSupport::Duration
      if expired?(name: name, expires: expires)
        set name: name, value: yield, expires: DateTime.now + expires
      else
        self[name][:value]
      end
    end

  end

  def cache_data
    @cache_memo_data
  end

  def cache_for(expires, &blk)
    @cache_memo_data ||= CacheData.new({})
    @cache_memo_data.value caller_locations(1,1)[0].label.to_sym, expires, &blk
  end
end


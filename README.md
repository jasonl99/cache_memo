# cache_memo gem

This gem improves on typical memoziation techiques by allowing the memoized value to expire after a user-defined duration.

Typically, memoization looks like this:

```ruby
def expensive_method
  @expensive_value ||= perform_expensive_calculation
end
```

This is fine most of the time.  However, you occassionaly want to refresh the memoized data, and there's no simple way to do this.  The cache_memo gem makes it easier:

```ruby
class MyClass
  include CacheMemo
  
  def expensive_method
    cache_for(5.minutes) {perform_expensive_calculation}
  end

end
    
```

Now, when expensive_method is called, it will return the memoized value unless the specified duration has passed, at which time it will rerun the expensive calculation.

The gem caches this data internally in a subclassed hash.

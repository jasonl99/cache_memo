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
    cache_for(10.seconds) {perform_expensive_calculation}
  end

  def really_expensive_method
    cache_for(10.minutes) {perform_expensive_calculation}
  end

end
    
```

Now, when expensive_method is called, it will return the memoized value unless the specified duration has passed, at which time it will rerun the expensive calculation.

The gem caches this data internally in a subclassed hash.

Suppose we do the following:

```ruby
my_object = MyClass.new
my_object.expensive_calculation         # 23
my_object.really_expensive_calculation  # 8599

```

expensive_method will return 23 for the next ten seconds, after which it will be recalculated.  The same holds true for really_expensive_method; it will return 8599 for 10 minutes.

You can view the current cache data as well:

```ruby
my_object.cache_data

{
:expensive_calculation=>{
    :value=>23, 
    :expires=>Wed, 21 Jan 2015 12:45:01 -0500
    }, 
 :really_expensive_calculation=>{
    :value=>8599, 
    :expires=>Wed, 21 Jan 2015 12:55:05 -0500
    }
}
```

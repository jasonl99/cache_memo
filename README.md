# cache_memo gem

** Please note:  this gem is experimental, and is subject to change. ** 

This gem improves on typical memoziation techiques by allowing the memoized value to expire after a user-defined duration.

Typically, memoization looks like this:

```ruby
def expensive_method
  @expensive_value ||= perform_expensive_calculation
end
```

This is fine most of the time.  However, you occassionaly want to refresh the memoized data, and there's no simple way to do this.  The cache_memo gem makes it easier.  Suppose we have a class with three methods we'd like to cache:

```ruby
class MyClass
  include CacheMemo

  def hello_user(user)
    cache_for(10.minutes, user) do
      say_hello_to(user)
    end
  end

  def daily_sales(date)
    # we anything other than today for a full day, but today for 5 minutes.
    cache_duration = date < Date.today ? 1.day : 5.minutes
    cache_for(cache_duration, date) do
      look_up_sales_for(date)
    end
  end

  def gross_domestic_product(country, year)
    cache_for(1.day, country) do
      calculate_gdp(country)
    end
  end

end

```

We'll warm the cache with some values.  This isn't neecessary, we just want to fill the cache and take a look at it.


```ruby
my_object = MyClass.new

# country_list is just an array of United States, Germany, Japan, etc.
# Find the gdp for each country in our list.
country_list.each do {|country| my_object.country_gdp(country, 2014)}

# Now calculate daily sales for the last week
(0..6).to_a.each {|day| my_object.daily_sales day.days.ago}

# Finally say hello to the current user
my_object.say_hello(current_user)



```
The cache creates a signature for each set of parameters.  To keep the cache fast as possible, if the parameters are simple and small, they signature is simply the array of parameters.  However, if the signature is large, we instead calculate a SHA1 digest on the string of the object.  Slower, but much less memory use.  

The signature now becomes the key under the method that is being cached.  The internal structure is much easier to understand when you see it printed out.  Given the code that we ran above, here's how the cache's internal data looks:


```ruby
my_object.cache_data

{:country_gdp=>
    {:writes=>11,
     ["United States", 2014]=>{:value=>5073172496, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["Germany", 2014]=>{:value=>5078641691, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["Japan", 2014]=>{:value=>5054080185, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["China", 2014]=>{:value=>5087291886, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["United Kindgom", 2014]=>{:value=>5021651076, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["Brazil", 2014]=>{:value=>5001475008, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["Italy", 2014]=>{:value=>5065918210, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["Russia", 2014]=>{:value=>5042426304, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["Canada", 2014]=>{:value=>5004410384, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["India", 2014]=>{:value=>5009832923, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     ["Australia'", 2014]=>{:value=>5098798449, :expires=>Sun, 25 Jan 2015 19:49:38 -0500},
     :reads=>3496},
   :daily_sales=>
    {:writes=>7,
     [Sun, 25 Jan 2015 00:49:56 UTC +00:00]=>{:value=>421, :expires=>Sat, 24 Jan 2015 19:54:56 -0500},
     [Sat, 24 Jan 2015 00:49:56 UTC +00:00]=>{:value=>564, :expires=>Sat, 24 Jan 2015 19:54:56 -0500},
     [Fri, 23 Jan 2015 00:49:56 UTC +00:00]=>{:value=>559, :expires=>Sun, 25 Jan 2015 19:49:56 -0500},
     [Thu, 22 Jan 2015 00:49:56 UTC +00:00]=>{:value=>427, :expires=>Sun, 25 Jan 2015 19:49:56 -0500},
     [Wed, 21 Jan 2015 00:49:56 UTC +00:00]=>{:value=>280, :expires=>Sun, 25 Jan 2015 19:49:56 -0500},
     [Tue, 20 Jan 2015 00:49:56 UTC +00:00]=>{:value=>981, :expires=>Sun, 25 Jan 2015 19:49:56 -0500},
     [Mon, 19 Jan 2015 00:49:56 UTC +00:00]=>{:value=>531, :expires=>Sun, 25 Jan 2015 19:49:56 -0500}},
   :hello_user=>{:writes=>1, "e5645a7eaaacba8aaac7f40cf74afbc982bbbb66"=>{:value=>"Hello, Jason Landry", :expires=>Sat, 24 Jan 2015 20:00:09 -0500}}}
```


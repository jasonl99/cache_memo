# cache_memo gem

This gem improves on typical memoziation techiques by allowing the
memoized value to expire after a user-defined duration.

Typically, memoization looks like this:

```ruby
def expensive_method
  @expensive_value ||= perform_expensive_calculation
end
```

This is fine most of the time.  However, you occassionaly want to
refresh the memoized data, and there's no simple way to do this.  The
cache_memo gem makes it easier:

```ruby
class MyClass
  include CacheMemo
 
  def user_posts(user)
    # this will create a digest for a cache key
    cache_for(10.minutes, user) do
      get_user_posts
    end

  def daily_sales(date)
  cache_duration = date < Date.today ? 1.day : 5.minutes  #no need to
recalulate other day's sales
  cache_for(5.minutes, date) do
      get_daily_sales_from_server
    end
  end

  def gross_domestic_product(country)
    cache_for(1.day, country) do
      calculate_gdp(country)
    end
  end

end

```


```ruby
my_object = MyClass.new
my_object.daily_sales(Date.today)  # 15000.00
my_object.daily_sales(Date.yesterday) #12000
my_object.calculate_gdp('United States')  # 16700000000000
my_object.calculate_gdp('Germany')        #  3700000000000

```
Daily sales will be recalculated every ten minutes.

The parameter signatures will be an array of passed parameters, unless
the string representation of that array is more than 100 characters
(chosen arbitrarily), in which case the signature will be a SHA1 digest.

With gross_domestic_product, each country have its own
cached value.  Looking at the cache_data, you can see the parameter
signatures as text, whereas the user_posts signature is a SHA1 hash.


```ruby
my_object.cache_data

{
  :daily_sales=>{
    [Thu 22 Jan 2015] => {
      :value=>15000,
      :expires=>Wed, 22 Jan 2015 12:45:01 -0500  # expires in five
minutes (called on the same day)
      },
    [Wed 21 Jan 2015] => {
      :value=>12000,
      :expires=>Wed, 23 Jan 2015 12:45:01 -0500  # expires in a day
      },
    },
 :gross_domestic_product=>
    "United States" => {
      :value=>16700000000000
      :expires=>Wed, 21 Jan 2015 12:55:05 -0500
      }
    "Germany"=> {
      :value=>3700000000000
      :expires=>Wed, 21 Jan 2015 12:56:15 -0500
      }
 :user_posts=>
    "c3d7fc8a0650d009342d3083c1e9521c11286890" => {
      :value=>[652,5123,661,2315]
      :expires=>Wed, 21 Jan 2015 12:55:05 -0500
      }
    "2e3afe9391f303ba72e522ff1363c831b6ac252f"=> {
      :value=>[15,25,13]
      :expires=>Wed, 21 Jan 2015 12:56:15 -0500
      }
}

```

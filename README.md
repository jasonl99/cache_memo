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

  def daily_sales
    cache_for(5.minutes) do
      get_daily_sales_from_server
    end
  end

  def gross_domestic_product(country)
    cache_for(1.day) do
      calculate_gdp(country)
    end
  end

end

```


```ruby
my_object = MyClass.new
my_object.daily_sales         # 15000.00
my_object.calculate_gdp('United States')  # 16700000000000
my_object.calculate_gdp('Germany')        #  3700000000000

```
Daily sales will be recalculated every ten minutes.

With gross_domestic_product, not only will each country have its own
cached value.  Looking at the cache_data, you can see the parameter
signatures, and the two for United States and Germany.

```ruby
my_object.cache_data

{
:daily_sales=>{
    "97d170e1550eee4afc0af065b78cda302a97674c" => {
      :value=>15000,
      :expires=>Wed, 21 Jan 2015 12:45:01 -0500
      },
    }
 :gross_domestic_product=>
    "768685ca582abd0af2fbb57ca37752aa98c9372b" => {
      :value=>16700000000000
      :expires=>Wed, 21 Jan 2015 12:55:05 -0500
      }
    "17d53e0e6a68acdf80b78d4f9d868c8736db2cec"=> {
      :value=>3700000000000
      :expires=>Wed, 21 Jan 2015 12:56:15 -0500
      }

}
```

Gem::Specification.new do |s|
  s.name        = 'cache_memo'
  s.version     = '0.0.1'
  s.date        = '2015-01-21'
  s.summary     = "Memoizes values that expire after supplied duration"
  s.description = "Rather than memoizing once and forever holding that value, this allows your memoized value to expire periodically"
  s.authors     = ["Jason Landry"]
  s.email       = "jasonl99@fastmail.com"
  s.required_ruby_version = '>= 2.0'
  s.files       = ["lib/cache_memo.rb"]
  s.license       = 'MIT'
end

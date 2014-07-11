require 'rack/jekyll'

use Rack::WWW, :predicate => lambda { |env|
  Rack::Request.new(env).host == "chasingthewhale.cc"
}

run Rack::Jekyll.new
require "#{File.dirname(__FILE__)}/lib/mise-web"

# Serve these URLs without auth

use Rack::Static, :root => './public', :urls => ['/favicon.ico', '/mise.css', '/mise-logo.png']

# Replace this with your desired auth middleware. NOTE: the default
# update hook must be modified to use the password you set here.

use Rack::Auth::Basic do |username, password|
  password == 'changeme'
end

use Rack::Protection, :except => :http_origin

run MiseEnPlace

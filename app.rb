require 'env'

require 'sinatra'
require 'slim'

require "screenshotter"
require 'queue_classic'
require 'oily_png'
require 'image_diff'
require 'base64'
require 'open-uri'

configure :development do
  require 'rack/reloader'
  Sinatra::Application.reset!
  use Rack::Reloader
end

set :slim, pretty: true, format: :html5
set :views, File.join(settings.root, "views")
set :server, :puma

get '/' do
  slim :index
end

post '/diff' do
    puts "Queuing diff request with params #{params}"
    QC.enqueue "ImageDiffer.do_image_diff", params
    status 200
    "OK"
end

post '/puts_callback' do
  data = params[:data]
  puts data
end

post '/snap' do
  url      = params[:url]
  callback = params[:callback]
  width    = params[:width] && params[:width].to_i
  height   = params[:height] && params[:height].to_i
  format   = params[:format]

  possible = Screenshotter.plan(
    format: format,
    width: width,
    height: height,
    url: url,
    callback: callback)

  if possible
    status 200
    "OK"
  else
    status 400
    "ERROR"
  end
end

get '/admin/queue' do
  queue_name = params[:queue] || QC::QUEUE
  QC::Queries.count(queue_name).to_s
end
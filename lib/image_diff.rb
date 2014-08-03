require 'chunky_png'
include ChunkyPNG::Color

def diff_images(images)
	
	images.first.height.times do |y|
		images.first.row(y).each_with_index do |pixel, x|
			images.last[x,y] = rgb(
				r(pixel) + r(images.last[x,y]) - 2 * [r(pixel), r(images.last[x,y])].min,
				g(pixel) + g(images.last[x,y]) - 2 * [g(pixel), g(images.last[x,y])].min,
				b(pixel) + b(images.last[x,y]) - 2 * [b(pixel), b(images.last[x,y])].min
			)
		end
	end
	return images.last.to_blob
end

def image_diff_respond(status, params = {})
	params[:status] = status
	uri                   = URI.parse(params["callback"])
	http                  = Net::HTTP.new(uri.host, uri.port)
	http.ssl_timeout      = 5
	http.open_timeout     = 5
	http.read_timeout     = 10
	http.continue_timeout = 10
	http.use_ssl          = true if uri.scheme == "https"
	headers               = {'Content-Type' => 'application/json'}
	request               = Net::HTTP::Post.new(uri.request_uri, headers)
	request["User-Agent"] = "grabbalicious"
	puts 'About to dump json'
	request.body          = MultiJson.dump(params)
	puts 'Done dumping json'
	http.request(request)
rescue => e
	log_exception e

	if params[:status] == :success
		params[:error] = e.class.name
		params.delete(:imageData)
		image_diff_respond(:error, params)
	end
end
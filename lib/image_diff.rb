require 'oily_png'
require 'base64'
require 'open-uri'
include ChunkyPNG::Color

class ImageDiffer
	def self.do_image_diff(params)
		require 'open-uri'
		puts params
	    url_a = params["url_a"]
	    url_b = params["url_b"]
	    callback = params["callback"]
	    puts 'Opening file a'
	    contents_a  = open(url_a) {|f| f.read}
	    puts 'Opening file b'
	    contents_b  = open(url_b) {|f| f.read}
	    puts 'Opened files, turning into PNG objects'
	    image_a = ChunkyPNG::Image.from_blob(contents_a)
	    image_b = ChunkyPNG::Image.from_blob(contents_b)
	    puts 'Diffing files'
	    diff_info = diff_images([image_a, image_b])
	    diff = diff_info[:image];
	    diff_found = diff_info[:diff]
	    puts 'Encoding files'
	    encoded_diff = Base64.encode64(diff)
	    params = {}
	    params.merge!(
	        "imageData" => encoded_diff,
	        "diffFound" => diff_found,
	        "callback" => callback)
	    puts 'Sending response'
	    image_diff_respond(:success, params)
	    puts 'Request complete!'
	rescue => error
		puts error
	end

	def self.diff_images(images)
		puts 'Diffing images'
		diff_found = false
		images.first.height.times do |y|
			images.first.row(y).each_with_index do |pixel, x|
				images.last[x,y] = rgb(
					r(pixel) + r(images.last[x,y]) - 2 * [r(pixel), r(images.last[x,y])].min,
					g(pixel) + g(images.last[x,y]) - 2 * [g(pixel), g(images.last[x,y])].min,
					b(pixel) + b(images.last[x,y]) - 2 * [b(pixel), b(images.last[x,y])].min
				)
				if r(images.last[x,y]) > 0 || g(images.last[x,y]) > 0 || b(images.last[x,y]) > 0)
					diff_found = true
				end
			end
		end
		return {image: images.last.to_blob, diff: diff_found}
	end

	def self.image_diff_respond(status, params = {})
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
end
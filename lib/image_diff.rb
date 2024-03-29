require 'oily_png'
require 'base64'
require 'open-uri'
require 'tempfile'
require 'fileutils'
require 'net/http'
include ChunkyPNG::Color

class ImageDiffer
	def self.do_image_diff_image_magic(params)
		puts "Doing image_magic"
		puts params
	    url_a = params["url_a"]
	    url_b = params["url_b"]
	    callback = params["callback"]
	    diff_found = true
	    Tempfile.open('output_file') do |output_file|
	    	puts "Output tempfile opened at #{output_file.path}"
		    Tempfile.open('file_a') do |file_a|
				puts "Tempfile opened at #{file_a.path}"
				puts "wget #{url_a} --output-document #{file_a.path}"
				`wget #{url_a} --output-document #{file_a.path}`
				Tempfile.open('file_b') do |file_b|
					puts "wget #{url_b} --output-document #{file_b.path}"
					`wget #{url_b} --output-document #{file_b.path}`

					width_a = `identify -format '%w' #{file_a.path}`.strip
					height_a = `identify -format '%h' #{file_a.path}`.strip
					width_b = `identify -format '%w' #{file_b.path}`.strip
					height_b = `identify -format '%h' #{file_b.path}`.strip

					if height_a != height_b || width_a != width_b
						puts `identify #{file_a.path}`
						puts `identify #{file_b.path}`
						puts "Need to convert file, running: convert #{file_a.path} -background black -extent #{width_b}x#{height_b} #{file_a.path}"
						convert_res = `convert #{file_a.path} -background black -extent #{width_b}x#{height_b} #{file_a.path}`
					end

					puts "Tempfile opened at #{file_b.path}"
					compare_options = "-metric PAE"
          compare_command = "compare #{file_a.path} #{file_b.path} #{compare_options} #{output_file.path}"
          puts "Running compare command: #{compare_command}"
          compare_output = `#{compare_command}`
				    puts "Output from compare: #{compare_output}"
				    if compare_output.include? "image widths or heights differ"
				    	raise "Images were different sizes, couldn't diff"
				    end
				    diff_found = !FileUtils.compare_file(file_a.path, file_b.path)
				end
			end
			outfile_contents = open(output_file.path) {|f| f.read}
	    	encode_and_send_diff(outfile_contents, diff_found, callback)
	    end
	    return :success
	rescue => error
		puts "Error diffing images: #{error}"
		return :failure
	end

	def self.encode_and_send_diff(diff, diff_found, callback)
		puts 'Encoding files'
	    puts 'Found non-zero diff' if diff_found
	    puts 'No diff detected' if !diff_found
	    encoded_diff = Base64.encode64(diff)
	    params = {}
	    params.merge!(
	        "imageData" => encoded_diff,
	        "diffFound" => diff_found,
	        "callback" => callback)
	    puts 'Sending response'
	    image_diff_respond(:success, params)
	    puts 'Request complete!'
	end

	def self.do_image_diff_ruby(params)
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
	    encode_and_send_diff(diff, diff_found, callback)
	    return :success
	rescue => error
		puts "Error"
		puts error
		return :failure
	end

	def self.do_image_diff(params)
		success = self.do_image_diff_image_magic(params)
		if success == :success
			return
		else
			puts "Couldn't diff using compare, using Ruby code instead"
			self.do_image_diff_ruby(params)
		end
	end

	def self.diff_images(images)
		puts 'Diffing images directly'
		diff_found = false
		images.first.height.times do |y|
			images.first.row(y).each_with_index do |pixel, x|
				images.last[x,y] = rgb(
					r(pixel) + r(images.last[x,y]) - 2 * [r(pixel), r(images.last[x,y])].min,
					g(pixel) + g(images.last[x,y]) - 2 * [g(pixel), g(images.last[x,y])].min,
					b(pixel) + b(images.last[x,y]) - 2 * [b(pixel), b(images.last[x,y])].min
				)
				if r(images.last[x,y]) > 0 || g(images.last[x,y]) > 0 || b(images.last[x,y]) > 0
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

def log_exception(e)
  STDERR.puts "#{e.class}: #{e.message}"
  STDERR.puts e.backtrace.join("\n")
end

#!/usr/bin/ruby

require 'optparse'
require "net/http"

class Crawler
	STYLESHEET = /<link (.*?)>/
	REL = /rel=["|'](.*?)["|']/
	HREF = /href=["|'](.*?)["|']/
	SCRIPT = /<script (type=["|'].*?["|'] )?src=(.*?)><\/script>/
	LINK = /<a href=["|'](.*?)["|'].*?>/
	IMAGES = /<img.*?src=["|'](.*?)["|'].*?>/

	attr_accessor :depth, :domain, :uri

	def initialize(url, depth, pages)
		@domain = url
		@uri = URI.parse(url)
		@http = Net::HTTP.new(uri.host, uri.port)
		@visited = []
		@depth = depth
		@pages = pages
	end

	def request(req)
		@http.request(req)
	end

	def get(url)
		get_r = Net::HTTP::Get.new(url)
		request(get_r)
	end

	def crawl(url="/", currDepth = 0)
		@visited.push url
		page = get(url).body
		padding "Url: #{url}", currDepth

		padding "Link tags:", currDepth
		stylesheet = page.scan(STYLESHEET)
		strip_stylesheet_link(stylesheet, currDepth)

		print_scripts page, currDepth
		print_elems page, currDepth

		links = page.scan(LINK)
		new_links = []
		links.each do |link|
			link = link[0]
			if link[0] != "/"
				if link.include? @domain
					new_links.push link[@domain.length..-1]
				end
			else
				new_links.push link
			end
		end

		puts ""

		new_links.uniq!

		new_links.each do |link|
			if(!is_visited?(link))
				if (currDepth <= @depth && @visited.count <= @pages )
					d = currDepth + 1
					crawl(link, d)
				end
			end
		end
	end

	def is_visited?(url)
		@visited.each do |v_url|
			if v_url == url
				return true
			end
		end
		return false
	end

	def strip_stylesheet_link(data, currDepth)
		data.each do |attrs|
			attrs = attrs[0]
			rel = "#{attrs}".match(REL).captures[0]
			href = "#{attrs}".match(HREF).captures[0]
			padding "  #{rel} #{href}", currDepth
		end
	end

	def print_scripts(page, currDepth)
		match = page.scan(SCRIPT)
		padding "Scripts:", currDepth
		match.each do |elem|
			padding "  #{elem[1]}", currDepth
		end
	end

	def print_elems(page, currDepth)
		match = page.scan(IMAGES)
		padding "Images:", currDepth
		match.each do |elem|
			padding "  #{elem[0]}", currDepth
		end
	end

	def padding(str, currDepth)
		puts "#{"\t"*currDepth}#{str}"
	end

end



# Options hash
depth = 5
pages = 10

parser = OptionParser.new do |opts|
	opts.banner = "Utility to parse authentication linux logs"

	opts.on('-d', "--depth [depth]", 'crawling depth') do |d|
		begin
			Float d
		rescue
			puts ("Depth must be an integer!")
			exit
		end
		depth = d;
	end

	opts.on('-p', "--pages [pages]", 'maximum nuber of pages') do |p|
		begin
			Float d
		rescue
			puts ("Pages must be an integer!")
			exit
		end
		pages = p;
	end

	opts.on('-h', 'Displays Help') do
		puts opts
		exit
	end
end

begin
	parser.parse!
rescue
	puts "unknown option!"
	#puts parser.help
	exit
end

url = "#{ARGV[0]}"
DOMAIN_REGEX = /(\w*):\/\/(.*\.\w+)\/?/

match = url.match(DOMAIN_REGEX)
if(match == nil || match.captures.count != 2)
	puts "Malformed url!"
	exit
end

protocol = match.captures[0]
if( protocol != "http" && protocol != "https")
	puts "Protocol not supported"
	exit
end

crawler = Crawler.new(url, depth, pages)
crawler.crawl

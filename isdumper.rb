require 'httpclient'
require 'uri'
require 'ftools'
require 'thread'
require 'net/http'
require 'time'

class ISDumper

	attr_accessor :username, :password, :images
	attr_accessor :imagesCount, :pagesCount
	attr_accessor :listOfLinks, :bucketOfFail
	
	attr_accessor :prependTimestamp
	
	def initialize(username, password)
		@username = username
		@password = password
		@cookiesHash = {}
		@listOfLinks = []
		@fileNames = {}
		@http = HTTPClient.new

		@bucketOfFail = []
		@bucketSync = Mutex.new

		Thread.abort_on_exception = true
	end

	def Login
		post = {:username => @username, :password => @password, :stay_logged_in => 'true', :format => 'json'}
		res = @http.post('http://imageshack.us/auth.php', post)
		
		#json parsing
		data = res.content
		dataHash = {}
		data.gsub('{','').gsub('}','').gsub('"','').split(',').each do |l|
			sp = l.split ':'
			dataHash[sp[0]] = sp[1]
		end
		
		# {status: false}
		return false if dataHash.count == 1
		
		return true
	end

	def GetLinkList
		res = @http.get 'http://my.imageshack.us/v_images.php'
				
		str = res.body.to_s
		
		#<input type="hidden" id="inumpages" value="42"/>
		numPagesRE = /<input type="hidden" id="inumpages" value="(\d+)"\/>/m
		@pagesCount = numPagesRE.match(str)[1].to_i

		#<input type="hidden" id="inumitems" value="1759"/>
		numPagesRE = /<input type="hidden" id="inumitems" value="(\d+)"\/>/m
		@imagesCount = numPagesRE.match(str)[1].to_i
		
		@listOfLinks = []
		
		ExtractLinks(str)
		
		currentPage = 3
		
		while currentPage <= @pagesCount do
			str = @http.get("http://my.imageshack.us/images.php?ipage=#{currentPage}").body
			ExtractLinks(str)
			currentPage = currentPage + 2
			puts "Getting links... #{@listOfLinks.count} (finished #{100.0*(currentPage-1)/@pagesCount}%)"
		end
		
		puts "Found #{@listOfLinks.count} links (#{@imagesCount - @listOfLinks.count} missing)"
		
	end
	
	def ExtractLinks(str)
		megaRE = /<div id="[^"]*"><div class="ii">[^<]*<\/div><div class="is">(\d+)<\/div><div class="if">([^<]*)<\/div><div class="ib">(\d+)<\/div><div class="it">[^<]*<\/div><div class="id">([^<]*)<\/div><div class="ip">[^<]*<\/div><div class="ic">[^<]*<\/div><div class="isz">[^<]*<\/div><div class="ist">[^<]*<\/div><div class="tags">[^<]*(?:<\/div><\/div>)?/m
		
		found = 0
		
		m = megaRE.match str
		while m != nil
			_is = m[1]
			_if = m[2]
			_ib = m[3]
			_time = m[4]
			
			link = "http://img#{_is}.imageshack.us/img#{_is}/#{_ib}/#{_if}"
			
			fname = _if
			fname = Time.parse(_time).to_i.to_s + '_' + fname if @prependTimestamp
			@fileNames[link] = fname
			
			@listOfLinks.push link
			m = megaRE.match m.post_match
			found = found + 1
		end
	end
	
	def DownloadOne(link)
		tries = 0
		result = nil
		#begin
		while result == nil
			begin
				resp = @http.get link
				
				case resp.http_header.status_code
				when 404
					#puts "Image #{link} does not exist"
					return nil
				when 200
					#do nothing
				else
					puts "Code #{resp.http_header.status_code} from #{link}"
				end
				result = resp.body
				
			rescue HTTPClient::ConnectTimeoutError, HTTPClient::BadResponseError, Errno::EINVAL, Errno::ETIMEDOUT, SocketError
				tries = tries + 1
				if tries > 2:
					@bucketSync.synchronize { @bucketOfFail.push link }
					return nil
				end
				result = nil
				sleep 1
			end
		end
		
		return result
	end
	
	def DownloadAll(dir,threadCount = 10)
		
		@http.cookie_manager = nil
		
		fails = 0
		done = 0
		total = @listOfLinks.count
		l = Mutex.new
		threads = []
		
		Dir.mkdir(dir) if not File::exist?(dir)
		
		for tid in 0...threadCount
		
			threads.push Thread.new {
				lnk = ''
				l.synchronize { lnk = @listOfLinks.pop if @listOfLinks.count > 0 }
				
				while lnk != nil
					
					data = DownloadOne(lnk)
					
					if data != nil:
						fName = @fileNames[lnk]
						while File::exist?(dir+'/'+fName)
							fName = fName.split('.')
							fName[-2].succ!
							fName = fName.join('.')
						end
						f = File.new(dir+'/'+fName,"wb")
						f.write data
						f.close
					end
					
					l.synchronize{
						if data != nil then done = done + 1 else fails = fails + 1 end
						puts "#{done+fails}/#{total} (saved #{done}, failed #{fails}) (left #{@listOfLinks.count})"
						lnk = nil
						lnk = @listOfLinks.pop if @listOfLinks.count > 0
					}
				end
			}
		end
		
		threads.each do |t|
			t.join
		end
	end
	
end
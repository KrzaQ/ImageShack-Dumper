require 'httpclient'
require 'uri'
require 'ftools'
require 'thread'
require 'net/http'

class ISDumper

	attr_accessor :username, :password, :images
	attr_accessor :imagesCount, :pagesCount
	
	def initialize(username, password)
		@username = username
		@password = password
		@cookiesHash = {}
		@listOfLinks = []
	end

	def Login
		@http = HTTPClient.new
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
		megaRE = /<div id="[^"]*"><div class="ii">[^<]*<\/div><div class="is">(\d+)<\/div><div class="if">([^<]*)<\/div><div class="ib">(\d+)<\/div><div class="it">[^<]*<\/div><div class="id">[^<]*<\/div><div class="ip">[^<]*<\/div><div class="ic">[^<]*<\/div><div class="isz">[^<]*<\/div><div class="ist">[^<]*<\/div><div class="tags">[^<]*(?:<\/div><\/div>)?/m
		
		found = 0
		
		m = megaRE.match str
		while m != nil
			_is = m[1]
			_if = m[2]
			_ib = m[3]
			@listOfLinks.push "http://img#{_is}.imageshack.us/img#{_is}/#{_ib}/#{_if}"
			m = megaRE.match m.post_match
			found = found + 1
		end
	end
	
	def DownloadOne(link)
		tries = 0
		result = nil
		while result == nil
			begin
				result = @http.get_content(link)
			rescue HTTPClient::ConnectTimeoutError
				result = nil
				sleep 1
			rescue Errno::ETIMEDOUT
				result = nil
				sleep 1
			rescue HTTPClient::BadResponseError
				tries = tries + 1
				result = nil
				if tries > 2:
					puts "can't download #{link} :("
					return result
				end
				sleep 0.5
			end
		end
		return result
	end
	
	def DownloadAll(dir,threadCount = 10)
		
		fails = 0
		done = 0
		total = @listOfLinks.count
		l = Mutex.new
		threads = []
		
		Dir.mkdir(dir) if not File::exist?(dir)
		
		for unnecessary in 0...threadCount
		
			threads.push Thread.new {
				lnk = ''
				l.synchronize { lnk = @listOfLinks.pop }
				
				while lnk != nil
					
					data = DownloadOne(lnk)
					
					if data == nil:
						l.synchronize{
							fails = fails + 1
							puts "#{done}/#{total} (fails: #{fails})"
							lnk = @listOfLinks.pop
						}
						next
					end
					
					fName = lnk.split('/')[-1]
					
					while File::exist?(dir+'/'+fName)
						fName = fName.split('.')
						fName[-2].succ!
						fName = fName.join('.')
					end
					
					f = File.new(dir+'/'+fName,"wb")
					f.write data
					f.close
					
					l.synchronize{
						done = done + 1
						puts "#{done}/#{total} (fails: #{fails})"
						lnk = @listOfLinks.pop
					}
				end
				
			}
		
		end
	
		threads.each do |t|
			t.join
		end
	end
	
end
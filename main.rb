require 'uri'
require 'net/http'
require 'ftools'
require 'thread'

require 'isdumper'

options = {}

ARGV.each do |a|
	sp = a.split('=',2)
	sp[0].slice!(0)
	puts "[#{sp[0]}] = #{sp[1]}"
	options[sp[0]] = sp[1]
end

if not options.include?('u'):
	print 'please type your username: '
	STDOUT.flush
	options['u'] = STDIN.gets.gsub("\n",'')
end

if not options.include?('p'):
	print 'please type your password: '
	STDOUT.flush
	options['p'] = STDIN.gets.gsub("\n",'')
end

if not options.include?('p') or not options.include?('u'):
	puts "incorrect syntax, options p and u must be used"
	exit()
end

dir = 'imageshack-dump'
dir = options['d'] if options.include?('d')

threads = 12
threads = options['t'].to_i if options.include?('t')

prependTimestamp = false
prependTimestamp = options['timestamp'] == 'true' if options.include?('timestamp')

dump = ISDumper.new(options['u'],options['p'])
dump.prependTimestamp = prependTimestamp

if not dump.Login():
	puts "login failed."
	exit()
end

dump.GetLinkList

dump.DownloadAll(dir,threads)

puts "saving failed, but possibly recoverable (non 404'd) links to failed.txt"

f = File.new(dir+'/failed.txt',"w")
dump.bucketOfFail.each do |link|
	f.puts link
end
f.close

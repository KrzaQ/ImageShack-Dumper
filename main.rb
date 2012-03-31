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
	options['u'] = STDIN.gets.gsub("\n",'')
end

if not options.include?('p'):
	print 'please type your password: '
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

dump = ISDumper.new(options['u'],options['p'])

if not dump.Login():
	puts "login failed."
	exit()
end

dump.GetLinkList

dump.DownloadAll(dir,threads)

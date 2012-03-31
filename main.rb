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

if not options.include?('p') or not options.include?('u'):
	puts "incorrect syntax, options p and u must be used"
	exit()
end

dump = ISDumper.new(options['u'],options['p'])

if not dump.Login():
	puts "login failed."
	exit()
end

dump.GetLinkList

dump.DownloadAll('dir',10)
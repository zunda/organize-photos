#!/usr/bin/ruby
#
# usage: ruby timestamp-photos.rb path [path ...]
#
# modifies mtime of the files according to EXIF information
# If EXIF is not available, timestamp will be applied assuming sequence
# in input
#
# example for a dry run:
#	ruby ~/organize-photos/timestamp-photos.rb -n * 2>&1 |\
#	tee timestamp-photos.`date +%Y%m%d`.log
#
# Copyright (C) 2011 by zunda <zunda at freeshell.org>
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#

require 'exif'	# requires ruby-exif package
require 'fileutils'
require 'optparse'

DisplayTimeFormat = "%Y-%m-%d %H:%M:%S"
TimeIncrement = 1

class Image
	DateTag = 'Date and Time (original)'	# in EXIF
	DateTimeFormat = %r|\A\d{4,4}:\d\d:\d\d [\d ]{2,2}:[\d ]{2,2}:[\d ]{2,2}\z|	# http://www.exif.org/Exif2-2.PDF p.36

	attr_reader :time

	def initialize(path)
		@time = nil
		begin
			x = Exif.new(path)[DateTag]
			@time = Time.local(*x.scan(/\d+/)) if x and x.match(DateTimeFormat)
		rescue Exif::NotExifFormat
		rescue ArgumentError
		end
	end
end

class Conf
	attr_accessor :dry_run
	def initialize
		@dry_run = false
	end
end

def set_mtime(path, mtime, conf)
	atime = File.atime(path)
	unless conf.dry_run
		File.utime(atime, mtime, path)
		$stderr.puts "#{path}\tmtime is now #{mtime.strftime(DisplayTimeFormat)}"
	else
		$stderr.puts "#{path}\tmtime will be #{mtime.strftime(DisplayTimeFormat)}"
	end
end

conf = Conf.new
opt = OptionParser.new
opt.banner = "usage: #{opt.program_name} [options] file file..."
opt.on('-n', 'makes a dry run'){conf.dry_run = true}
opt.parse!(ARGV)

curtime = nil
backorder = Array.new
ARGV.each do |srcpath|
	image = Image.new(srcpath)

	if image.time
		curtime = image.time
		backtime = curtime - TimeIncrement
		while backpath = backorder.pop
			set_mtime(backpath, backtime, conf)
			backtime -= TimeIncrement
		end
	elsif curtime
		curtime += TimeIncrement
	end

	if curtime
		set_mtime(srcpath, curtime, conf)
	else
		backorder.push(srcpath)
	end
end

unless backorder.empty?
	$stderr.puts "No EXIF timestamp acuired"
end

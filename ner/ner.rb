#!/usr/bin/env ruby

require 'pry'
require 'nokogiri'
require 'csv'
require 'text'


xml_fn = ARGV.pop
csv_fn = ARGV.pop

xml = File.read(xml_fn)
csv = CSV.open(csv_fn, :headers=> false, :col_sep => "\t")

print "XML=#{xml_fn}\n"
#binding.pry
rows = csv.to_a
names = rows.map{|r| r[0] }
names.uniq!

names.each_with_index do |name,i|
  if name
    xml.gsub!(/\b(#{name})\b/, '<name>\1</name>') if name.match(/\s/)
  end
end

File.write("out.xml", xml)

p 'foo'

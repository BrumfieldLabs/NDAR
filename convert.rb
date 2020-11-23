#!/usr/bin/env ruby

require 'pry'
require 'nokogiri'
require 'csv'
require 'text'


xml_fn = ARGV.pop
csv_fn = ARGV.pop

xml = Nokogiri::XML(File.read(xml_fn))
csv = CSV.open(csv_fn, :headers=> true)
rows = csv.to_a


docs = xml.xpath('//doc')

docs.each_with_index do |doc, i|
  p i
  row = rows[i]
  csv_title = row['Title'].downcase.gsub(/\s+/m, '')
  source = doc.xpath('./title/source').first
  if source
    xml_title = doc.xpath('./title').text.gsub(source.text, '').downcase.gsub(/\s+/m, '')
  else
    xml_title = doc.xpath('./title').text.downcase.gsub(/\s+/m, '')
  end
  
  
  if xml_title == csv_title
    print "#{i}\nstring match\n\n"
  else
    raw_ld = Text::Levenshtein.distance(xml_title, csv_title)
    ratio = raw_ld.to_f / ((xml_title.size + csv_title.size).to_f / 2)
    print "#{i}\nLevenschtein/Avgerage Size =\t#{ratio}\n"
    print "#{xml_title}\n#{csv_title}\n\n"
  end
  
end


p 'foo'

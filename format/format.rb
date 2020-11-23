#!/usr/bin/env ruby

require 'pry'
require 'nokogiri'
require 'csv'
require 'text'
require 'active_support'
require 'active_support/core_ext'
require 'titleize'


def squish_whitespace(doc, element_name)
  # find the title element
  doc.xpath("#{element_name}").each do |element|
    element.traverse do |node|
      if node.text?
        node.content = node.text.gsub(/\s\s*/m, ' ')
      end
    end
  end
end


def format_element(doc, element_name)
  # find the title element
  xpath = "/#{element_name}|*/#{element_name}|*/*/#{element_name}|*/*/*/#{element_name}"
#  print "#{xpath}:\t#{doc.xpath(xpath).count}\n"
  doc.xpath(xpath).each do |element|
    # get a copy of this XML node so we don't mess up the original
    working = element.dup
    # delete the source note element if there is one
    #working.traverse { |n| n.unlink if n.name == "sn" }
    # format the title
    if element.text.match /----/ # handle redactions specially
      formatted = element.text.split(/\s/).map { |word| word.match(/----/) ? word : word.titleize }.join(" ").squish
    else
      formatted = element.text.titleize.squish  
    end
    # set the attribue
    element['formatted'] = formatted    
  end
end

def format_title(doc)
  # find the title element
  title = doc.xpath('./title').first
  # get a copy of this XML node so we don't mess up the original
  working = title.dup
  # delete the source note element if there is one
  working.traverse { |n| n.unlink if n.name == "sn" }
  # format the title
  formatted = working.text.titleize.squish
  # set the attribue
  title['formatted'] = formatted
end

BODY_ELEMENTS = ['p', 'p2', 'p3', 'table', 'center', 'ctr', 'ind']

def encapsulate_doc_body(doc)
  in_body = false
  seen_body = false
  docbody_element = nil
  postscript_element = nil
#  binding.pry
  doc.elements.each do |element|
    # should this element be in a docbody?
    if BODY_ELEMENTS.include? element.name
      # are we in a docbody?
      if !in_body
        # we are not in a docbody; the element should be in teh docbody; create a docbody, add the element, swap its location
        if seen_body 
          element.add_previous_sibling('<postscript/>')
        else
          element.add_previous_sibling('<docBody/>')
        end
        docbody_element = element.previous
        element.unlink
        in_body = true
        seen_body = true
      end
      # we are in a docbody; the element should be in the docbody: add it to the docbody
      docbody_element.add_child(element)
    else
      if in_body
        # we are in a docbody; the element should not be in the docbody: close the tag and return from the method -- we're dond
        in_body = false
#      	return
      end
      # we are not in a docbody; the element should nto be in the docbody; continue to the next element
    end
  end
  # binding.pry
  # p 'foo'
end

def flatten_doc_body(doc)
  doc.xpath("//docBody").each do |body|
#    binding.pry
    previous = body.previous_element
    body.children.each do |child|
#      binding.pry
      previous.add_next_sibling(child)
      previous = child
    end
    body.unlink
  end
#  binding.pry
end

# these are actually in enc tags, apparently, though I don't see that in v2
def indentify_sigs_and_sals(doc)
  doc.xpath("*/enc").each do |ind|
    ind.children.each do |element|
      element['enclosure'] = 'true'
    end
  end
end


xml_fn = ARGV.pop

xml = Nokogiri::XML(File.read(xml_fn))

docs = xml.xpath('//doc')

docs.each_with_index do |doc, i|
  binding.pry unless doc.xpath('./title').first
  print "#{i}\t#{doc.xpath('./title').first.text.squish}\n"
  format_title(doc)  
  ['ship', 'pub', 'name', 'aut', 'rec'].each do |element_name|
    format_element(doc, element_name)  
  end

  ['p', 'p2', 'p3',  'title', 'src', 'note'].each do |element_name|
    squish_whitespace(doc, element_name)
  end
#  flatten_doc_body(doc)
  
  encapsulate_doc_body(doc)
  indentify_sigs_and_sals(doc)
end

File.write("out.xml", xml.to_xml)



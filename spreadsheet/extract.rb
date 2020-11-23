#!/usr/bin/env ruby

require 'pry'
require 'nokogiri'
require 'csv'
require 'text'
require 'active_support'
require 'active_support/core_ext'
require 'titleize'


# We need to read all of the ships/names/places/publications in a file
# for each element, we should create a CSV row containing
# * Document ID
# * Verbatim text
# * Enclosing element (allowing us to differentiate recipients and authors
# * Proposed canonical name
# * Derivative fields for sorting and grouping potential candidates

def element_to_components(element)
  # verbatim name
  # parent
  formatted = element['formatted']
  unless formatted
    if element.text.match /----/ # handle redactions specially
      formatted = element.text.split(/\s/).map { |word| word.match(/----/) ? word : word.titleize }.join(" ").squish
    else
      formatted = element.text.titleize.squish  
    end
  end
  formatted = formatted.gsub(/(\d{3,}) (\d{3,})/, '\1-\2') # for some bizarre reason, titleize replaces hyphens with spaces, which we have to undo for date ranges
  { :verbatim => element.text, :formatted => formatted, :container => element.parent.name, :path => element.path }
end

def context(doc, verbatim)
  context = doc.text.split(verbatim)
  "#{context[0].last(40)} #{verbatim.upcase} #{context[1].first(40)}".squish
end


def surname(verbatim)
end

def forenames(verbatim)

end

WORDS = []
VESSEL_TYPES = {
  'brig' => 'Brig', 
  'brigg' => 'Brig', 
  'brigt' => 'Brigantine', 
  'brigne' => 'Brigantine', 
  'brigantine' => 'Brigantine', 
  'boat' => 'Boat',
  'convoy' => 'Convoy',
  'corvette' => 'Corvette',
  'cutter' => 'Cutter',
  'frigate' => 'Frigate',
  'galley' => 'Galley',
  'h.m.s' => 'H.M.S.',
  'man-of-War' => 'Man of War',
  'schooner' => 'Schooner',
  'scooner' => 'Schooner',
  'schooners' => 'Schooner',
  'schr' => 'Schooner',
  'sr' => 'Schooner',
  'ship' => 'Ship',
  'ships' => 'Ship',
  'sloop' => 'Sloop',
  'snow' => 'Snow',
  'tender' => 'Tender',
  'transport' => 'Transport'
}

def formalize_ship(doc, verbatim, formatted)
  formatted = normalize(formatted)
  # find the previous word.  If it is a list of ship types, add it in parens
  context = doc.text.split(verbatim)
  previous_words = context[0].squish.split(/\s/)
  previous_word = previous_words.last
  if previous_word
    if previous_word.downcase == 'the'
      previous_word = previous_words[previous_words.size - 2]
    end

    # compare the previous word with the list, removing any final punctuation
    # try again removing final s
    type = VESSEL_TYPES[previous_word.downcase.gsub(/\W$/,'').gsub(/s$/,'')] 
  else
    # no previous words -- the ship name appears at the beginning of the document
    type = nil
  end
  # occasionally the vessel type follows the vessel name
  unless type
    following_word = context[1].squish.split(/\s/).first
    type = VESSEL_TYPES[following_word.downcase.gsub(/\W$/,'').gsub(/s$/,'')] 
  end

  # either we have the type by now or we don't
  if type
    "#{formatted} (#{type})"
  else
    formatted
  end
end

def normalize(verbatim)
  verbatim.gsub("&", 'and')
end


def extract_ships(docs)
  ship_csv = CSV.open("ships.csv", 'wb')
  ship_csv << ['DOC_ID', 'CANONICAL', 'CONTEXT', 'FORMATTED', 'VERBATIM', 'CONTAINING_ELEMENT', 'PATH_TO_ELEMENT']

  element_name = "ship"
  docs.each_with_index do |doc, i|
    doc_id = doc['id'] 
    xpath = "/#{element_name}|*/#{element_name}|*/*/#{element_name}|*/*/*/#{element_name}"
    doc.xpath(xpath).each do |element|
      components = element_to_components(element)
      verbatim = components[:verbatim]
      formatted = components[:formatted]
      context = context(doc, verbatim)
      binding.pry if formatted.blank?
      formal_name = formalize_ship(doc, verbatim, formatted)
      ship_csv << [doc_id, formal_name, context, formatted, verbatim, components[:container], components[:path]]
    end
  end
  ship_csv.close
end


def formalize_pub(formatted)
  formatted.gsub(/[\[\]]*/, '')  # remove interpolation brackets
end

def extract_pubs(docs)
  pub_csv = CSV.open("pubs.csv", 'wb')
  pub_csv << ['DOC_ID', 'CANONICAL', 'CONTEXT', 'FORMATTED', 'VERBATIM', 'CONTAINING_ELEMENT', 'PATH_TO_ELEMENT']

  docs.each_with_index do |doc, i|
    doc_id = doc['id'] 
    element_name = "pub"
    xpath = "/#{element_name}|*/#{element_name}|*/*/#{element_name}|*/*/*/#{element_name}"
    doc.xpath(xpath).each do |element|
      components = element_to_components(element)
      verbatim = components[:verbatim]
      formatted = components[:formatted]
      context = context(doc, verbatim)
      formal_name = formalize_pub(formatted)
      pub_csv << [doc_id, formal_name, context, formatted, verbatim, components[:container], components[:path]]
    end
  end
  pub_csv.close
end

def extract_places(docs)
  place_csv = CSV.open("places.csv", 'wb')
  place_csv << ['DOC_ID', 'CANONICAL', 'CONTEXT', 'FORMATTED', 'VERBATIM', 'CONTAINING_ELEMENT', 'PATH_TO_ELEMENT']

  docs.each_with_index do |doc, i|
    doc_id = doc['id'] 
    element_name = 'plc'
    xpath = "/#{element_name}|*/#{element_name}|*/*/#{element_name}|*/*/*/#{element_name}"
    doc.xpath(xpath).each do |element|
      components = element_to_components(element)
      verbatim = components[:verbatim]
      formatted = components[:formatted]
      binding.pry unless formatted
      context = context(doc, verbatim)
      formal_name = formalize_pub(formatted)
      place_csv << [doc_id, formal_name, context, formatted, verbatim, components[:container], components[:path]]
    end
  end
  place_csv.close
end

TITLES =  {
 "Admiral"=>"Admiral",
 "Adml"=>"Admiral",
 "Admll"=>"Admiral",
 "Cap"=>"Captain",
 "Capain"=>"Captain",
 "Capn"=>"Captain",
 "Capt"=>"Captain",
 "Capt."=>"Captain",
 "Capta"=>"Captain",
 "Captain"=>"Captain",
 "Captn"=>"Captain",
 "Captn."=>"Captain",
 "Captns"=>"Captain",
 "Col"=>"Colonel",
 "Col."=>"Colonel",
 "Colo"=>"Colonel",
 "Doctor"=>"Doctor",
 "Doctr"=>"Doctor",
 "Dr."=>"Doctor",
 "Ensign"=>"Ensign",
 "General"=>"General",
 "Generals"=>"General",
 "Geniral"=>"General",
 "Genl"=>"General",
 "Governor"=>"Governor",
 "Govr"=>"Governor",
 "Honble"=>"Honorable",
 "Honourable"=>"Honorable",
 "Ld"=>"Lord",
 "Lieut"=>"Lieutenant",
 "Lieut."=>"Lieutenant",
 "Lieutenant"=>"Lieutenant",
 "Lieutenat"=>"Lieutenant",
 "Lieutt"=>"Lieutenant",
 "Lord"=>"Lord",
 "Lt."=>"Lieutenant",
 "M."=>"Monsieur",
 "Major"=>"Major",
 "Majr"=>"Major",
 "Messrs"=>"Messrs",
 "Monsieur"=>"Monsieur",
 "Monsr"=>"Monsieur",
 "Mr"=>"Mr.",
 "Mr."=>"Mr.",
 "Mrs"=>"Mrs.",
 "Mrss"=>"Mrs.",
 "Rev."=>"Reverend",
 "mr."=>"Mr."}

SUFFIXES = {
  "Esq" => "Esquire",
  "Esq." => "Esquire",
  "Esqr" => "Esquire",
  "Esquire" => "Esquire",
  "Esqrs" => "Esquire",
  "Lieu" => "Lieutenant",
  "Jr" => "Junior",
  "Jun" => "Junior",
  "Junr" => "Junior",
  "Junior" => "Junior",
  "Master" => "Master",
  "Mast" => "Master",
  "Masr" => "Master",
  "Mastr" => "Master",
  "Mate" => "Mate",
  "r.n." => "R.N.",
  "Secry" => "Secretery",
  "Secrety" => "Secretery"
}

def formalize_name(formatted)
#  formatted = normalize(formatted)
  words = formatted.split(/\s/)

  # find any titles
  first = words.first
  title = TITLES[first]
  if title
    words.shift
  end

  # find any date suffixes
  last = words.last
  dates = nil
  binding.pry unless last
  if last.match(/\d\d\d\d/)
    dates = words.pop
  end

  # find any title suffixes
  last = words.last
  suffix = SUFFIXES[last]
  if suffix
    words.pop
  end

  surname = words.pop
  surname.gsub!(/,$/, '') # strip trailing comma
  fornames = words.join(' ')
  if fornames.blank?
    formatted = surname
  else
    formatted = "#{surname}, #{words.join(' ')}"
  end

  if suffix
    formatted = "#{formatted}, #{suffix}"
  end

  if title
    formatted = "#{formatted} (#{title})"
  end

  if dates
    formatted = "#{formatted} #{dates}"
  end

  formatted
end


def extract_names(docs, element_name)
  name_csv = CSV.open("#{element_name}.csv", 'wb')
  name_csv << ['DOC_ID', 'CANONICAL', 'CONTEXT', 'FORMATTED', 'VERBATIM', 'CONTAINING_ELEMENT', 'PATH_TO_ELEMENT']

  firsts = []
  lasts = []

  docs.each_with_index do |doc, i|
    doc_id = doc['id'] 
    xpath = "/#{element_name}|*/#{element_name}|*/*/#{element_name}|*/*/*/#{element_name}"
    doc.xpath(xpath).each do |element|
      components = element_to_components(element)
      verbatim = components[:verbatim]
      words = verbatim.split(/\s/)
      formatted = components[:formatted]
      context = context(doc, verbatim)
      binding.pry if formatted == "Lieutenant"
      binding.pry if formatted.blank?
      formal_name = formalize_name(formatted)
      name_csv << [doc_id, formal_name, context, formatted, verbatim, components[:container], components[:path]]
    end
  end
  name_csv.close
end


REPOS = {"AAS"=>"American Antiquarian Society, Worcester",
 "AMAE"=>"Archives Du Ministère Des Affaires Étrangèrs,  Paris",
 "APS"=>"American Philosophical Society, Philadelphia",
 "BM"=>"British Museum, London",
 "CL"=>"William L. Clements Library, University of Michigan, Ann Arbor",
 "ConnHS"=>"Connecticut Historical Society, Hartford",
 "ConnSL"=>"Connecticut State Library, Hartford",
 "CUL"=>"Columbia University Library, New York",
 "CW"=>"Colonial Williamsburg, Williamsburg",
 "DAC"=>"Dominion (Public) Archives of Canada, Ottawa",
 "DLAR"=>
  "David Library of the American Revolution, Washington Crossing, Pennsylvania",
 "FDRL"=>"Franklin D. Roosevelt Library, Hyde Park, New York",
 "HL"=>"Hayes Library, Edenton, North Carolina",
 "HSD"=>"Historical Society of Delaware, Wilmington",
 "HSP"=>"Historical Society of Pennsylvania, Philadelphia",
 "HU"=>"Harvard University Library, Cambridge",
 "HUL"=>"Henry E. Huntington Library, San Marino, California",
 "JCBL"=>"John Carter Brown Library, Providence",
 "LC"=>"Library of Congress, Washington",
 "Mass. Arch."=>"Massachusetts Archives, Boston",
 "MassHS"=>"Massachusetts Historical Society, Boston",
 "Md. Arch."=>"Maryland Archives (Hall of Records), Annapolis",
 "MdHS"=>"Maryland Historical Society, Baltimore",
 "MeHS"=>"Maine Historical Society, Portland",
 "MHA"=>"Marine Historical Association, Mystic, Connecticut",
 "MNHP"=>"Morristown National Historical Park, Morristown, New Jersey",
 "NA"=>"National Archives, Washington",
 "NCDAH"=>"North Carolina Department of Archives and History, Raleigh",
 "NHA"=>"Nantucket Historical Association, Nantucket, Massachusetts",
 "NHCHS"=>"New Haven Colony Historical Society, New Haven",
 "NHS"=>"Newport Historical Society, Newport",
 "NLCHS"=>"New London County Historical Society, New London",
 "N.S. Arch."=>"Nova Scotia Archives, Halifax",
 "NYHS"=>"New-York Historical Society, New York",
 "NYPL"=>"New York Public Library, New York",
 "NYSL"=>"New York State Library, Albany",
 "Pa. Arch."=>"Pennsylvania Archives, Harrisburg",
 "PML"=>"Pierpont Morgan Library, New York",
 "PRO"=>"Public Record Office, London",
 "R.I. Arch."=>"Rhode Island Archives, Providence",
 "RIHS"=>"Rhode Island Historical Society, Providence",
 "SCHS"=>"South Carolina Historical Society, Charleston",
 "UVL"=>"University of Virginia Library, Charlottesville",
 "VHS"=>"Virginia Historical Society, Richmond",
 "VSL"=>"Virginia State Library, Richmond",
 "WPL"=>"Public Library, Whitehaven, England",
 "WSL"=>"William Salt Library, Stafford, England",
 "YUL"=>"Yale University Library, New Haven"
}

SOURCES = {
  "Graves's Conduct"=>
  "The Conduct of Vice-Admiral Graves in North America in 1774, 1775 and January 1776, Gay Transcript, I, 31, MassHS. Original in British Museum, Ms 14038",
 "Barker, Diary."=>
  "John Barker, The British in Boston Being the Diary of Lieutenant John Barker of the King's Own Regiment from November 15, 1774 to May 31, 1776; With Notes by Elizabeth Ellery Dana (Cambridge, 1924). ",
 "Balt. Com., LC."=>"Minutes of the Baltimore Committee, LC. ",
 "Bartlett, ed., Records of Rhode Island."=>
  "John Russell Bartlett, ed., Records of the Colony of Rhode Island and Providence Plantation in New England, 1770 to 1776 (Providence, 1862). ",
 "Saunders, comp., Records of North Carolina."=>
  "W. L. Saunders, comp., The Colonial Records of North Carolina (Raleigh, 1890). ",
 "White, ed., Beekman Papers."=>
  "Philip L. White, ed., The Beekman Mercantile Papers, 1746-1799 (New York, 1956). ",
 "Syrett, ed., Hamilton Papers."=>
  "Harold C. Syrett, ed., The Papers of Alexander Hamilton (New York and London 1961). ",
 "Bouton, ed., Documents and Records of New Hampshire."=>
  "Nathaniel Bouton, ed., Provincial Papers, Documents and Records Relating to the Province of New Hampshire From 1764 to 1776, (Nashua, 1873). ",
 "O'Callaghan, Colonial New York."=>
  "E. B. O'Callaghan, ed., Documents Relative to the Colonial History of the State of New York (Albany, 1850-1861). ",
 "Woolsey and Salmon Letter Book, LC."=>
  "Mercantile Letter Book of Woolsey and Salmon, Baltimore merchants, LC. ",
 "Fries, ed., Moravians in North Carolina."=>
  "Wachovia Archives, Winston-Salem, N.C.; printed in Adelaide L. Fries, ed., Records of the Moravians in North Carolina, (Raleigh, 1925).",
 "Loring, ed., Safety Committee of Wilmington, N.C."=>
  "Thomas Loring, ed., Proceedings of the Safety Committee of the Town of Wilmington, N.C. from 1774 to 1776 (Raleigh, 1844). ",
 "Ford, Commerce of Rhode Island."=>
  "W. C. Ford, ed., Commerce of Rhode Island, 1726-1800 (Boston, 1915). ",
 "Sabine, ed., Memoirs of William Smith."=>
  "William H. W. Sabine, ed., Historical Memoirs from 16 March 1763 to 9 July 1776 of William Smith, Historian of the Province of New York, Member of the Governor's Council and last Chief Justice of That Province under the Crown (New York, 1956). ",
 "Pa. Col. Rec."=>
  "Pennsylvania Colonial Records (Harrisburg, 1852).",
 "Barnes and Owen, eds., Sandwich Papers."=>
  "G. R. Barnes and J. H. Owen, eds., The Private Papers of John, Earl of Sandwich First Lord of the Admiralty 1771-1782 (London, 1932).",
 "Calendar of Historical Manuscripts, N.Y."=>
  "Calendar of Historical Manuscripts Relating to the War of the Revolution in the Office of the Secretary of State, Albany, N.Y. (Albany, 1868).",
 "Stiles, LC."=>
  "Dr. Ezra Stiles Literary Diary, I, 408, Force Transcript, LC. ",
 "Colden Papers."=>
  "The Letters and Papers of Cadwallader Colden (New York, 1923).",
 "Force, comp., American Archives."=>
  "Peter Force, comp., American Archives, Fourth Series (Washington, 1837-1853).",
 "Papers CC, NA."=>
  "Papers of the Continental Congress, 65, I, 9, NA. ",
 "Hazard et al., eds., Pennsylvania Archives."=>
  "Samuel Hazard et al., eds., Pennsylvania Archives (Philadelphia and Harrisburg, 1852-19-), 8th series.",
 "\"Oswald's Journal.\""=>
  "This journal in the form of a letter from Ticonderoga, dated May 23, I 775, was published in the New England Chronicle, Cambridge, June 1, 1775. While the name of the writer was not revealed in the letter as published, his identity may be readily ascertained through contemporary letters. ",
 "Ford, ed., JCC."=>
  "Worthington C. Ford, et al., eds., Journals of the Continental Congress (Washington, 1904-1937).",
 "Ford, ed., Lee."=>
  "W. C. Ford, ed., The Letters of William Lee (Brooklyn, 1878).",
 "Parliamentary History."=>
  "The Parliamentary History of England From the Earliest Period to the Year 1803 (London, 1813).",
 "Almon, ed., Remembrancer."=>
  "J. Almon, ed., The Remembrancer or Impartial Repository of Public Events for the Year 1775. (London, 1776).",
 "N.Y. Prov. Cong."=>
  "Journals of the Provincial Congress, Provincial Convention, Committee of Safety and Council of Safety of the State of New York, 1775-1776-1777, (Albany, 1842).",
 "Butterfield, ed., Adams Family Correspondence."=>
  "L. H. Butterfield, ed., The Adams Papers, Series II, Adams Family Correspondence (Cambridge, 1963). ",
 "Fitzpatrick, ed., Writings of Washington."=>
  "John C. Fitzpatrick, ed., The Writings of George Washington (Washington, 1921-1940). ",
 "Hastings, ed., Clinton Papers."=>
  "Hugh Hastings, ed., The Public Papers of George Clinton (New York, 1899). ",
 "Boyd, ed., Jefferson Papers."=>
  "Julian P. Boyd, ed., The Papers of Thomas Jefferson (Princeton, 1952).",
 "Warren-Adams Letters."=>
  "Warren-Adams Letters, Being Chiefly a Correspondence Among John Adams, Samuel Adams, and James Warren, 1743-1814 (Boston, 1917-25). ",
 "\"Nicholas Cooke Correspondence,\" AAS Proceedings."=>
  "\"Revolutionary Correspondence of Governor Nicholas Cooke,\" Proceedings of the American Antiquarian Society, New Series, XXXVI.",
 "Edes Diary."=>
  "A Diary of Peter Edes, The Oldest Printer in the United States, written during his confinement in Boston by the British one hundred and seven days in the year I 775, immediately after the Battle of Bunker Hill. Written by himself. [Bangor, Samuel S. Smith, Printer, 1837].",
 "Trumbull and Hoadley, eds., Connecticut Records."=>
  "J. H. Trumbull and C. J. Hoadley, eds., Public Records of the Colony of Connecticut 1636-1776 (Hartford, 1850-90).",
 "Abbatt, ed., Heath Memoirs."=>
  "William Abbatt, ed., Memoirs of Major-General William Heath By Himself (New York, 1901).",
 "Purviance, Baltimore Town Narrative."=>
  "U.S. Naval Papers, MdHS. Edited version in Robert Purviance, A Narrative of Events, which Occurred in Baltimore Town During the Revolutionary War (Baltimore, 1849). ",
 "Browne, ed., Arch. of Md. See Randolph to Maryland Convention, July 27, 1775."=>
  "William H. Browne, ed., Archives of Maryland (Baltimore, 1892). ",
 "Duane, ed., Marshall's Diary."=>
  "William Duane, ed., Extracts from the Diary of Christopher Marshall Kept in Philadelphia and Lancaster, During the American Revolution 1774-1781 (Albany, 1877).",
 "Adams, John Adams."=>"John Adams, The Works of John Adams. ",
 "Biddle, ed., Charles Biddle Autobiography."=>
  "James S. Biddle, ed., Autobiography of Charles Biddle, Vice-President of the Supreme Executive Council of Pennsylvania, 1745-1821 (Philadelphia, 1883).",
 "Va. Conv."=>
  "The Proceedings of the Convention of Delegates for the Counties and Corfiorations in the Colony of Virginia, held at Richmond Town in the County of Henrico (Richmond, 1816). ",
 "Preble, Prebles in America."=>
  "George Henry Preble, Genealogical Sketch of the First Three Generations of Prebles in America (Boston, 1868). ",
 "Council Letter Book, N.S. Arch."=>
  "Letter Book of the Governor and Council, Commencing October 19th, 1760 and ending in 1784, 214, N.S. Arch. ",
 "Gibbes, ed., Documentary History."=>
  "R. W. Gibbes, ed., Documentary History of the American Revolution, 1764-1776 . . . (New York, 1855).",
 "Council Minutes, N.S. Arch."=>
  "Minutes of Council Aug. 23, 1766 to Oct. 6, 1783, N.S. Arch. ",
 "Doniol, Histoire."=>
  "Henri Doniol, Histoire de la participation de la France à l'établissement des États-Unis d'Amérique (Paris, 1886-92), I, 156, translation. "
}


def formalize_repository(verbatim)
  formal = nil
  REPOS.each_pair do |abbrev,title|
    if verbatim.match(/#{abbrev}/)
      formal = title
      break
    end
  end

  formal
end

def formalize_book_source(verbatim)
  formal = nil
  SOURCES.each_pair do |abbrev,title|
    if verbatim.match(/#{abbrev}/)
      formal = title
      break
    end
  end
  formal
end

def extract_sources(docs)
  source_csv = CSV.open("sources.csv", 'wb')
  source_csv << ['DOC_ID', 'REPOSITORY', 'BOOK_SOURCE', 'VERBATIM', 'CONTAINING_ELEMENT', 'PATH_TO_ELEMENT']

  docs.each_with_index do |doc, i|
    doc_id = doc['id'] 
    element_name = 'src'
    xpath = "/#{element_name}|*/#{element_name}|*/*/#{element_name}|*/*/*/#{element_name}"
    doc.xpath(xpath).each do |element|
      components = element_to_components(element)
      verbatim = components[:verbatim]
      repository = formalize_repository(verbatim)
      book_source = formalize_book_source(verbatim)
      source_csv << [doc_id, repository, book_source, verbatim, components[:container], components[:path]]
    end
  end
  source_csv.close

end


########################
# Main routine
########################

xml_fn = ARGV.pop
xml = Nokogiri::XML(File.read(xml_fn))
docs = xml.xpath('//doc')

extract_ships(docs)
extract_pubs(docs)
extract_places(docs)
extract_names(docs,'aut')
extract_names(docs,'rec')
extract_sources(docs)

#binding.pry
#p SOURCES.size


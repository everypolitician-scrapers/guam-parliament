#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'
require 'fuzzy_match'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

terms = { 
  '33' => 'http://www.guamlegislature.com/senators_33rd.htm',
  '32' => 'http://www.guamlegislature.com/senators_32nd.htm',
  '31' => 'http://www.guamlegislature.com/senators_31st.htm',
  '30' => 'http://www.guamlegislature.com/senators_30th.htm',
}

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def party_id(party)
  return "rep" if party == 'Republican'
  return "dem" if party == 'Democratic'
  raise "No such party: #{party}"
end

def scrape_term(id, url)
  puts url
  noko = noko_for(url)

  noko.css('table.gallerytext').xpath('tr[.//span[@class="picturename"]]').each do |tr|
    begin
      name = tr.css('span.picturename').text
      # Multiple broken variations on official site
      name = "Tina Rose Muña Barnes" if name =~ /Tina.*Barnes/
    rescue
      puts "problem with #{name} = #{name.encoding}"
      next
    end
    data = { 
      name: name.tidy.gsub('Honorable ',''),
      image: tr.css('img.Galborder/@src').text,
      phone: tr.xpath('.//text()[contains(.,"Ph.:")]').text.tidy[/Ph.:\s*(.*)$/, 1].strip,
      fax: tr.xpath('.//text()[contains(.,"Fax:")]').text.to_s.tidy[/Fax:\s*(.*)$/, 1].to_s.strip,
      email: tr.css('a[href*="mailto:"]/@href').text.gsub('mailto:',''),
      term: id,
      source: url,
    }
    if fuzzied = @fuzzies.find(data[:name]) 
      wp_info = @party_lookup.find { |p| p[:name] == fuzzied }
      data[:party] = wp_info[:party]
      data[:party_id] = party_id(data[:party])
      data[:wikipedia] = URI.join('https://en.wikipedia.org/', wp_info[:wikipedia]).to_s unless wp_info[:wikipedia].to_s.empty?
    else
      warn "NO MATCH for #{data[:name]}"
      data[:party] = data[:party_id] = "unknown"
    end

    data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?
    # puts data
    ScraperWiki.save_sqlite([:name, :term], data)
  end
end

def parties_from_wikipedia(url)
  noko = noko_for(url)
  noko.xpath('.//table[.//th[contains(.,"Party Affiliation")]]//tr[td]').map do |tr|
    name, party, _ = tr.css('td')
    {
      name: name.text,
      wikipedia: name.css('a/@href').text,
      party: party.text,
    }
  end
end

@party_lookup = parties_from_wikipedia('https://en.wikipedia.org/w/index.php?title=Legislature_of_Guam&oldid=668991435')
@fuzzies = FuzzyMatch.new @party_lookup.map { |p| p[:name] }.uniq

terms.each do |id, url|
  scrape_term(id, url)
end

#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

terms = { 
  '33' => 'http://www.guamlegislature.com/senators_33rd.htm',
  '32' => 'http://www.guamlegislature.com/senators_32nd.htm',
  '31' => 'http://www.guamlegislature.com/senators_31st.htm',
  '30' => 'http://www.guamlegislature.com/senators_30th.htm',
}

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def scrape_term(id, url)
  puts url
  noko = noko_for(url)

  noko.css('table.gallerytext').xpath('tr[.//span[@class="picturename"]]').each do |tr|
    # party, party_id = party_info ( td.xpath('preceding::strong[1]').text )
    data = { 
      name: tr.css('span.picturename').text.gsub('Honorable ',' ').strip,
      image: tr.css('img.Galborder/@src').text,
      phone: tr.xpath('.//text()[contains(.,"Ph.:")]').text.gsub(/[[:space:]]+/, ' ')[/Ph.:\s*(.*)$/, 1].strip,
      fax: tr.xpath('.//text()[contains(.,"Fax:")]').text.to_s.gsub(/[[:space:]]+/, ' ')[/Fax:\s*(.*)$/, 1].to_s.strip,
      email: tr.css('a[href*="mailto:"]/@href').text.gsub('mailto:',''),
      # party: party,
      # party_id: party_id,
      term: id,
      source: url,
    }
    data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?
    puts data
    ScraperWiki.save_sqlite([:name, :term], data)
  end
end

terms.each do |id, url|
  scrape_term(id, url)
end

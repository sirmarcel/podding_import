# coding: utf-8

require 'rubygems'
require 'nokogiri'
require 'fileutils'
require 'yaml'
require 'time'
require 'redcarpet'
require 'reverse_markdown'
require 'pp'

module Importer
  class << self
    def forbidden_tags
      ["Retinauten", "Pilotenprüfung", "RTC"]
    end

    def show_map
      {
        /RTC (S\d\dE\d\d)/ => "rtc",
         /RTC(\d\d\d)/ => "rtc",
        /RTN(\d\d\d)/ => "rtn",
        /RTC PP E(\d\d)/ => "pp"
      }
    end

    def make_folders
      system "mkdir out/pp"
      system "mkdir out/rtc"
      system "mkdir out/rtn"
      system "mkdir out/default"
    end

    def find_show(title)
      show_map.each do |regex, show_name|
        if title =~ regex
          return show_name
        end
      end
      "default"
    end

    def find_name(title)
      show_map.each do |regex, show_name|
        if title =~ regex
          return show_name + "-" + $1
        end
      end
      "default"
    end

    def process(filename = "wordpress.xml")
      make_folders

      f = File.open(filename) 
      doc = Nokogiri::XML(f)
      f.close
      
      doc.css("channel item").each do |item|
        title_raw = item.css("title").text
        content_raw = item.xpath("content:encoded").text
        date_raw = item.css("pubDate").text
        tags_raw = item.css("category")

        if title_raw.include? ":"
          title = title_raw.split(":")[1].strip 
        else
          title = title_raw unless title
        end

        date = Date.parse(date_raw)

        if content_raw.include?("<!--more-->")
          teaser = content_raw.split("<!--more-->")[0]
          teaser = ReverseMarkdown.parse teaser
          shownotes = content_raw.split("<!--more-->")[1]
          shownotes = ReverseMarkdown.parse shownotes
        else # RTC specific format
          teaser = content_raw.partition(/<h[2-6]>/)[0]
          teaser = ReverseMarkdown.parse teaser if teaser
          teaser.gsub!("#","")
          shownotes = content_raw.partition(/<h[2-6]>/)[1] + content_raw.partition(/<h\d>/)[2]
          shownotes = ReverseMarkdown.parse shownotes
        end

        content = ReverseMarkdown.parse content_raw

        # Assume all Twitter links are hosts
        hosts_raw = content.scan(/\[(\w*)\]\(\s*https?:\/\/twitter.com\/\w+\s*\)/).flatten
        hosts = hosts_raw.map {|h| h.downcase }


        tags = tags_raw.each_with_object([]) do |cat, ary|
          tag = cat.text
          ary << tag unless forbidden_tags.include? tag
        end

        name = find_name(title_raw)
        show = find_show(title_raw)

    
        meta = {}
        meta["name"] = name
        meta["show"] = show
        meta["title"] = title
        meta["date"] = date
        meta["status"] = "published"
        meta["hosts"] = hosts

        # puts title
        # puts date
        # puts hosts
        # puts name
        # pp tags

        File.open(File.join("out",show,name + ".md"), "w") do |f|
          f.puts meta.to_yaml
          f.puts "---"
          f.puts "!!!"
          f.puts teaser
          f.puts "!!!"
          f.puts shownotes
        end
      end
    end
  end
end

Importer.process
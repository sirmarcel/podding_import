# coding: utf-8

# Podding Importer
sqrt(x(x+1) - y^2) + sqrt(a(a+1) - b^2)  
# This script converts an xml file exported by Wordpress into
# podding text files. 

# You can run it from the command line with an (optional) path to the file.
# It will create an "out" folder in the folder the script is in and 
# write the episodes in sub folders according to their show.
#
# This script will treat all episodes as published.
#
# It doesn't do anything with audio on purpose,
# you'll need to rename all files according to the podding conventions:
# #{ episode_name }-#{ format suffix }.#{ extension }
#
# If that task seems daunting to you, take a look at auphonic,
# and our gem "miniphonic" that interacts with it.

require 'rubygems'
require 'nokogiri'
require 'fileutils'
require 'yaml'
require 'time'
require 'reverse_markdown'

class PoddingImporter
  class << self

    # The importer will not write these categories / tags
    # into the files
    def forbidden_tags
      # Example: ["Retinauten", "Pilotenprüfung", "RTC"]
      []
    end

    # This hash will translate titles into show names and
    # episode numbers.
    # The keys should be regexes with their first match
    # group corresponding to the episode number,
    # the values are strings with the name of the show
    def show_map
      # Example
      # {
      #   /RTC (S\d\dE\d\d)/ => "rtc",
      #    /RTC(\d\d\d)/ => "rtc",
      #   /RTN(\d\d\d)/ => "rtn",
      #   /RTC PP E(\d\d)/ => "pp"
      # }
      {

      }
    end

    def make_folders
      system "mkdir out"
      show_map.values.each do |show|
        system "mkdir out/#{ show }"
      end
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

        # Assumes a title format like this:
        # RTN023: This is the title
        if title_raw.include? ":"
          title = title_raw.split(":")[1].strip 
        else
          title = title_raw unless title
        end

        date = Date.parse(date_raw)

        # Assumes that your shownotes are either below the Wordpresss <!-- more --> tag
        # or everything that follows a heading
        if content_raw.include?("<!--more-->")
          teaser = content_raw.split("<!--more-->")[0]
          teaser = ReverseMarkdown.parse teaser
          shownotes = content_raw.split("<!--more-->")[1]
          shownotes = ReverseMarkdown.parse shownotes
        else # take everything beyond the first h2 as shownotes
          teaser = content_raw.partition(/<h[2-6]>/)[0]
          teaser = ReverseMarkdown.parse teaser if teaser
          teaser.gsub!("#","")
          shownotes = content_raw.partition(/<h[2-6]>/)[1] + content_raw.partition(/<h\d>/)[2]
          shownotes = ReverseMarkdown.parse shownotes
        end

        content = ReverseMarkdown.parse content_raw

        # Assume all Twitter links are hosts
        # You'll probably need to change this for your podcast
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
        meta["tags"] = tags

        puts "Writing episode " + name

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

PoddingImporter.process(ARGV)
# Jekyll plugin for generating an rss 2.0 feed for posts
#
# Usage: place this file in the _plugins directory and set the required configuration
#        attributes in the _config.yml file
#
# Uses the following attributes in _config.yml:
#   name           - the name of the site
#   url            - the url of the site
#   description    - (optional) a description for the feed (if not specified will be generated from name)
#   author         - (optional) the author of the site (if not specified will be left blank)
#   copyright      - (optional) the copyright of the feed (if not specified will be left blank)
#   rss_path       - (optional) the path to the feed (if not specified "/" will be used)
#   rss_name       - (optional) the name of the rss file (if not specified "rss.xml" will be used)
#   rss_post_limit - (optional) the number of posts in the feed
#
# Author: Assaf Gelber <assaf.gelber@gmail.com>
# Site: http://agelber.com
# Source: http://github.com/agelber/jekyll-rss
#
# Distributed under the MIT license
# Copyright Assaf Gelber 2014

module Jekyll
  class RssFeed < Page; end

  class RssGenerator < Generator
    require 'net/http'
    priority :low
    safe true

    # Generates an rss 2.0 feed
    #
    # site - the site
    #
    # Returns nothing
    def generate(site)
      require 'rss'

      # Create the rss with the help of the RSS module
      rss = RSS::Maker.make("2.0") do |maker|
        maker.channel.title = site.config['name']
        maker.channel.link = site.config['url']
        maker.channel.description = site.config['description']
        maker.channel.author = site.config["author"]
        maker.channel.updated = site.posts.map { |p| p.date }.max
        maker.channel.copyright = site.config['copyright']
        maker.channel.language = site.config['language']
        maker.channel.itunes_subtitle = site.config['subtitle']
        maker.channel.itunes_author = site.config['author']
        maker.channel.itunes_summary = site.config['description']
        maker.channel.itunes_owner.itunes_name = site.config['author']
        maker.channel.itunes_owner.itunes_email = site.config['email']
        maker.channel.itunes_image = site.config['cover']
        
        category = maker.channel.itunes_categories.new_category
        category.text = site.config['category']
        category.new_category.text = site.config['subcategory']
        
        post_limit = (site.config['rss_post_limit'] - 1 rescue site.posts.count)

        site.posts.reverse[0..post_limit].each do |post|
          post.render(site.layouts, site.site_payload)
          maker.items.new_item do |item|
            link = "#{site.config['url']}#{post.url}"
            item.guid.content = link
            item.title = post.title
            item.link = link
            item.description = post.id
            item.updated = post.date
            item.itunes_author = site.config['author']
            item.itunes_subtitle = post.data['subtitle']
            item.itunes_summary = post.excerpt
            item.itunes_duration = post.data['duration']
            item.itunes_keywords = post.data['keywords']
            item.enclosure.url = post.data['audio_file_url']
            item.enclosure.type = "audio/mpeg"
            item.enclosure.length = get_file_size(post.data['audio_file_url'])   
          end
        end
      end

      # Ruby RSS lib doesn't have a documented way of using CDATA, so we're replacing it in post.
 
      rss = rss.to_s
      site.posts.each do |post|
        rss = rss.gsub("<description>#{post.id}</description>", "<description><![CDATA[#{post.content}]]></description>")
      end
 
      # File creation and writing
      rss_path = ensure_slashes(site.config['rss_path'] || "/")
      rss_name = site.config['rss_name'] || "rss.xml"
      full_path = File.join(site.dest, rss_path)
      ensure_dir(full_path)
      File.open("#{full_path}#{rss_name}", "w") { |f| f.write(rss) }

      # Add the feed page to the site pages
      site.pages << Jekyll::RssFeed.new(site, site.dest, rss_path, rss_name)
    end

    private

    def get_file_size(url) 
      uri = URI.parse(url)
      res = Net::HTTP.start(uri.host, uri.port) do |http| 
        http.head(uri.path) 
      end
      res['content-length']
    end

    # Ensures the given path has leading and trailing slashes
    #
    # path - the string path
    #
    # Return the path with leading and trailing slashes
    def ensure_slashes(path)
      ensure_leading_slash(ensure_trailing_slash(path))
    end

    # Ensures the given path has a leading slash
    #
    # path - the string path
    #
    # Returns the path with a leading slash
    def ensure_leading_slash(path)
      path[0] == "/" ? path : "/#{path}"
    end

    # Ensures the given path has a trailing slash
    #
    # path - the string path
    #
    # Returns the path with a trailing slash
    def ensure_trailing_slash(path)
      path[-1] == "/" ? path : "#{path}/"
    end

    # Ensures the given directory exists
    #
    # path - the string path of the directory
    #
    # Returns nothing
    def ensure_dir(path)
      FileUtils.mkdir_p(path)
    end
  end
end

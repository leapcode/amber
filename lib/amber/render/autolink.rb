# encoding: utf-8
# adapted from https://github.com/tenderlove/rails_autolink
# MIT license

module Amber::Render::Autolink

  def self.auto_link(text)
    auto_link_email_addresses(auto_link_urls(text))
  end

  private

  AUTO_LINK_RE = %r{
      (?: ((?:ed2k|ftp|http|https|irc|mailto|news|gopher|nntp|telnet|webcal|xmpp|callto|feed|svn|urn|aim|rsync|tag|ssh|sftp|rtsp|afs|file):)// | www\. )
      [^\s<\u00A0]+
    }ix

  # regexps for determining context, used high-volume
  AUTO_LINK_CRE = [/<[^>]+$/, /^[^>]*>/, /<a\b.*?>/i, /<\/a>/i]

  AUTO_EMAIL_LOCAL_RE = /[\w.!#\$%&'*\/=?^`{|}~+-]/
  AUTO_EMAIL_RE = /[\w.!#\$%+-]\.?#{AUTO_EMAIL_LOCAL_RE}*@[\w-]+(?:\.[\w-]+)+/

  BRACKETS = { ']' => '[', ')' => '(', '}' => '{' }

  WORD_PATTERN = RUBY_VERSION < '1.9' ? '\w' : '\p{Word}'

  # Turns all urls into clickable links.  If a block is given, each url
  # is yielded and the result is used as the link text.
  def self.auto_link_urls(text)
    text.gsub(AUTO_LINK_RE) do
      scheme, href = $1, $&
      punctuation = []

      if auto_linked?($`, $')
        # do not change string; URL is already linked
        href
      else
        # don't include trailing punctuation character as part of the URL
        while href.sub!(/[^#{WORD_PATTERN}\/-]$/, '')
          punctuation.push $&
          if opening = BRACKETS[punctuation.last] and href.scan(opening).size > href.scan(punctuation.last).size
            href << punctuation.pop
            break
          end
        end

        #link_text = block_given?? yield(href) : href
        link_text = href.sub(/^#{scheme}\/\//,'')
        href = 'http://' + href unless scheme
        %(<a href="#{href}">#{link_text}</a>) + punctuation.reverse.join('')
      end
    end
  end

  # Turns all email addresses into clickable links.
  def self.auto_link_email_addresses(text)
    text.gsub(AUTO_EMAIL_RE) do
      text = $&

      if auto_linked?($`, $')
        text
      else
        #display_text = (block_given?) ? yield(text) : text
        #display_text = text
        text.gsub!('@', '&#064').gsub!('.', '&#046;')
        %(<a href="mailto:#{text}">#{text}</a>)
      end
    end
  end

  # Detects already linked context or position in the middle of a tag
  def self.auto_linked?(left, right)
    (left =~ AUTO_LINK_CRE[0] and right =~ AUTO_LINK_CRE[1]) or
      (left.rindex(AUTO_LINK_CRE[2]) and $' !~ AUTO_LINK_CRE[3])
  end

end
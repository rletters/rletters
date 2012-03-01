# -*- encoding : utf-8 -*-

# Markup generators common to all of RLetters
module ApplicationHelper
  
  # Render a partial from the 'static' folder
  #
  # This helper either renders a partial from the 'static' folder (if it
  # exists), or renders the '.dist' version of that partial (otherwise).
  #
  # @api public
  # @return [undefined]
  # @example Render the 'about' partial
  #   <%= render_static_partial 'about' %>
  def render_static_partial(partial)
    if File.exists?(Rails.root.join('app', 'views', 'static', "_#{partial}.markdown"))
      render :file => Rails.root.join('app', 'views', 'static', "_#{partial}.markdown")
    else
      render :file => Rails.root.join('app', 'views', 'static', "_#{partial}.markdown.dist")
    end
  end
  
  # Fetch a translation and run it through a Markdown parser
  #
  # Some translations are stored in the translation database as Markdown
  # markup.  This helper fetches them and then runs them through Kramdown.
  #
  # @api public
  # @param [String] key the lookup key for the translation requested
  # @return [String] the requested translation, parsed as Markdown
  # @example Parse the translation for +error.not_found+ as Markdown
  #   <%= t_md(:"error.not_found") %>
  def t_md(key)
    Kramdown::Document.new(I18n.t(key)).to_html.html_safe
  end
end

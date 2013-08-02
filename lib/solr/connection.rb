# -*- encoding : utf-8 -*-

module Solr

  # Methods for managing the singleton connection to the Solr server
  module Connection
    
    class << self
      # Cache the connection to solr
      #
      # @return [RSolr::Client] the cached Solr connection object
      attr_accessor :solr
      
      # Cache the URL to Solr, to detect changes in the configuration panel
      #
      # @return [String] the URL for connecting to Solr
      attr_accessor :url
    end

    # Get a response from Solr
    #
    # This method breaks out the retrieval of a Solr response in order to
    # provide for easier testing.
    #
    # @api private
    # @param [Hash] params
    # @return [RSolr::Ext.response] Solr search result
    def self.find(params)
      begin
        get_solr
        ret = Connection.solr.find params
      rescue Exception => e
        Rails.logger.warn "Connection to Solr failed: #{e.inspect}"
        RSolr::Ext::Response::Base.new({ 'response' => { 'docs' => [] } }, 'select', params)
      end
    end

    # Get the info/statistics hash from Solr
    #
    # This method retrieves information about the Solr server, including the
    # Solr and Java versions.
    #
    # @api private
    # @return [Hash] Unprocessed Solr response
    def self.info
      begin
        get_solr
        ret = Connection.solr.get 'admin/system'
      rescue Exception => e
        Rails.logger.warn "Connection to Solr failed: #{e.inspect}"
        {}
      end
    end

    private

    # Retrieve the Solr connection object
    #
    # Since the Solr connection URL can be updated on the fly using the
    # administration console, this method has to watch the value of that URL
    # and reconnect to Solr when required.
    #
    # @api private
    # @return [RSolr::Client] Solr connection object
    def self.get_solr
      Connection.solr ||= RSolr::Ext.connect(
        url: Setting.solr_server_url,
        read_timeout: Setting.solr_timeout.to_i,
        open_timeout: Setting.solr_timeout.to_i
      )

      # Make sure that we update the Solr connection when we change the
      # Solr URL, since it can be dynamically modified in the admin panel
      Connection.url ||= Setting.solr_server_url
      if Connection.url != Setting.solr_server_url
        Connection.url = Setting.solr_server_url

        Connection.solr = RSolr::Ext.connect(
          url: Setting.solr_server_url,
          read_timeout: Setting.solr_timeout.to_i,
          open_timeout: Setting.solr_timeout.to_i
        )
      end
    end
  end
end

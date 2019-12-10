require "chef-api"
require "jmespath"
require "uri"

module InspecPlugins::Chef
  class Input < Inspec.plugin(2, :input)
    VALID_PATTERNS = [
      Regexp.new("^databag://[^/]+/[^/]+/.+$"),
      Regexp.new("^node://[^/]+/attributes/.+$"),
    ].freeze

    attr_reader :plugin_conf, :chef_endpoint, :chef_client, :chef_api_key
    attr_reader :chef_api

    # Set up new class
    def initialize
      @plugin_conf = Inspec::Config.cached.fetch_plugin_config("inspec-chef")

      @chef_endpoint = fetch_plugin_setting("endpoint")
      @chef_client   = fetch_plugin_setting("client")
      @chef_api_key  = fetch_plugin_setting("key")

      if chef_endpoint.nil? || chef_client.nil? || chef_api_key.nil?
        raise "ERROR: Need configuration of chef endpoint, client name and api key."
      end

      connect_to_chef_server
    end

    # Fetch method used for Input plugins
    def fetch(_profile_name, input_uri)
      return nil unless valid_plugin_input? input_uri

      input = parse_input(input_uri)

      if input[:type] == :databag
        data = get_databag_item(input[:object], input[:item])
      elsif input[:type] == :node
        data = get_attributes(input[:object]) if input[:item] == "attributes"
      end

      JMESPath.search(input[:query].join("."), data)
    end

    private

    # Get plugin setting via environment, config file or default
    def fetch_plugin_setting(setting_name, default = nil)
      env_var_name = "INSPEC_CHEF_#{setting_name.upcase}"
      config_name = "chef_api_#{setting_name.downcase}"
      ENV[env_var_name] || plugin_conf[config_name] || default
    end

    # Establish a Chef Server connection
    def connect_to_chef_server
      @chef_api ||= ChefAPI::Connection.new(
        endpoint: chef_endpoint,
        client:   chef_client,
        key:      chef_api_key
      )
    end

    # Retrieve a Databag item from Chef Server
    def get_databag_item(databag, item)
      chef_api.data_bag_item.fetch(item, bag: databag).data
    end

    # Retrieve attributes of a node
    def get_attributes(node)
      data = get_search(:node, "name:#{node}")

      merge_attributes(data)
    end

    # Low-level Chef search expression
    def get_search(index, expression)
      chef_api.search.query(index, expression).rows.first
    end

    # Merge attributes in hierarchy like Chef
    def merge_attributes(data)
      data["default"].merge(data["normal"]).merge(data["override"]).merge(data["automatic"])
    end

    # Verify if input is valid for this plugin
    def valid_plugin_input?(input)
      VALID_PATTERNS.any? { |regex| regex.match? input }
    end

    # Parse InSpec input name into Databag, Item and search query
    def parse_input(input_uri)
      uri = URI(input_uri)
      item, *components = uri.path.slice(1..-1).split("/")

      {
        type: uri.scheme.to_sym,
        object: uri.host,
        item: item,
        query: components,
      }
    end
  end
end

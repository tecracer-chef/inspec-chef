require "chef-api"
require "jmespath"
require "resolv"
require "uri"

module InspecPlugins::Chef
  class Input < Inspec.plugin(2, :input)
    VALID_PATTERNS = [
      Regexp.new("^databag://[^/]+/[^/]+/.+$"),
      Regexp.new("^node://[^/]*/attributes/.+$"),
    ].freeze

    attr_reader :plugin_conf, :chef_endpoint, :chef_client, :chef_api_key
    attr_reader :chef_api

    # Set up new class
    def initialize
      @plugin_conf = Inspec::Config.cached.fetch_plugin_config("inspec-chef")

      unless defined?(Kitchen)
        @chef_endpoint = fetch_plugin_setting("endpoint")
        @chef_client   = fetch_plugin_setting("client")
        @chef_api_key  = fetch_plugin_setting("key")

        if chef_endpoint.nil? || chef_client.nil? || chef_api_key.nil?
          raise "ERROR: Need configuration of chef endpoint, client name and api key."
        end

        connect_to_chef_server
      end
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

      result = JMESPath.search(input[:query].join("."), data)
      raise format("Could not resolve value for %s, check if databag/item or attribute exist", input_uri) if result.nil?

      result
    end

    private

    # Check if this is called from within TestKitchen
    def inside_testkitchen?
      !! defined?(::Kitchen::Logger)
    end

    # Check if this is an IP
    def ip?(ip_or_name)
      # Get address always returns an IP, so if nothing changes this was one
      Resolv.getaddress(ip_or_name) == ip_or_name
    rescue Resolv::ResolvError
      false
    end

    # Check if this is an FQDN
    def fqdn?(ip_or_name)
      # If it is not an IP but contains a Dot, it is an FQDN
      !ip?(ip_or_name) && ip_or_name.include?(".")
    end

    # Reach for Kitchen data and return its evaluated config
    def kitchen_provisioner_config
      require "binding_of_caller"
      kitchen = binding.callers.find { |b| b.frame_description == "verify" }.receiver

      kitchen.provisioner.send(:provided_config)
    end

    # Get plugin setting via environment, config file or default
    def fetch_plugin_setting(setting_name, default = nil)
      env_var_name = "INSPEC_CHEF_#{setting_name.upcase}"
      config_name = "chef_api_#{setting_name.downcase}"
      ENV[env_var_name] || plugin_conf[config_name] || default
    end

    # Get remote address for this scan from InSpec
    def inspec_target
      target = Inspec::Config.cached.final_options["target"]
      URI.parse(target)&.host
    end

    # Establish a Chef Server connection
    def connect_to_chef_server
      @chef_api ||= ChefAPI::Connection.new(
        endpoint: chef_endpoint,
        client:   chef_client,
        key:      chef_api_key
      )

      Inspec::Log.debug format("Connected to %s as client %s", chef_endpoint, chef_client)
    end

    # Retrieve a Databag item from Chef Server
    def get_databag_item(databag, item)
      unless inside_testkitchen?
        unless chef_api.data_bags.any? { |k| k.name == databag }
          raise format('Databag "%s" not found on Chef Infra Server', databag)
        end

        chef_api.data_bag_item.fetch(item, bag: databag).data
      else
        config = kitchen_provisioner_config
        filename = File.join(config[:data_bags_path], databag, item + ".json")

        begin
          return JSON.load(File.read(filename))
        rescue
          raise format("Error accessing databag file %s, check TestKitchen configuration", filename)
        end
      end
    end

    # Retrieve attributes of a node
    def get_attributes(node)
      unless inside_testkitchen?
        data = get_search(:node, "name:#{node}")

        merge_attributes(data)
      else
        kitchen_provisioner_config[:attributes]
      end
    end

    # Try to look up Chef Client name by the address requested
    def get_clientname(ip_or_name)
      query = "hostname:%<address>s"
      query = "ipaddress:%<address>s" if ip?(ip_or_name)
      query = "fqdn:%<address>s" if fqdn?(ip_or_name)
      result = get_search(:node, format(query, address: ip_or_name))
      Inspec::Log.debug format("Automatic lookup of node name (IPv4 or hostname) returned: %s", result&.fetch("name") || "(nothing)")

      # Try EC2 lookup, if nothing found (assuming public IP)
      if result.nil?
        query = "ec2_public_ipv4:%<address>s OR ec2_public_hostname:%<address>s"
        result = get_search(:node, format(query, address: ip_or_name))
        Inspec::Log.debug format("Automatic lookup of node name (EC2 public IPv4 or hostname) returned: %s", result&.fetch("name"))
      end

      # This will fail for cases like trying to connect to IPv6, so it will
      # need extension in the future

      result&.fetch("name") || raise(format("Unable too lookup remote Chef client name from %s", ip_or_name))
    end

    # Low-level Chef search expression
    def get_search(index, expression)
      chef_api.search.query(index, expression, rows: 1).rows.first
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
        object: uri.host || get_clientname(inspec_target),
        item: item,
        query: components,
      }
    end
  end
end

require "chef-api"
require "jmespath"
require "json"
require "resolv"
require "uri"

module InspecPlugins
  module Chef
    class Input < Inspec.plugin(2, :input)
      VALID_PATTERNS = [
        Regexp.new("^databag://[^/]+/[^/]+/.+$"),
        Regexp.new("^node://[^/]*/attributes/.+$"),
      ].freeze

      attr_reader :chef_server

      # ========================================================================
      # Dependency Injection

      attr_writer :inspec_config, :logger

      def inspec_config
        @inspec_config ||= Inspec::Config.cached
      end

      def logger
        @logger ||= Inspec::Log
      end

      # ========================================================================
      # Input Plugin API

      # Fetch method used for Input plugins
      def fetch(_profile_name, input_uri)
        logger.trace format("Inspec-Chef received query for input %<uri>s", uri: input_uri)
        return nil unless valid_plugin_input?(input_uri)

        logger.debug format("Inspec-Chef input schema detected")

        connect_to_chef_server

        input = parse_input(input_uri)
        if input[:type] == :databag
          data = get_databag_item(input[:object], input[:item])
        elsif input[:type] == :node && input[:item] == "attributes"
          # Search Chef node name, if no host given explicitly
          input[:object] = get_clientname(scan_target) unless input[:object] || inside_testkitchen?

          data = get_attributes(input[:object])
        end

        # Quote components to allow "-" as part of search query.
        # @see https://github.com/jmespath/jmespath.rb/issues/12
        expression = input[:query].map { |component| '"' + component + '"' }.join(".")
        result = JMESPath.search(expression, data)
        raise format("Could not resolve value for %s, check if databag/item or attribute exist", input_uri) unless result

        stringify(result)
      end

      private

      # ========================================================================
      # Helper Methods

      # Check if this is called from within TestKitchen
      def inside_testkitchen?
        !! defined?(::Kitchen)
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

      # Merge attributes in hierarchy like Chef
      def merge_attributes(data)
        data.fetch("default", {})
          .merge(data.fetch("normal", {}))
          .merge(data.fetch("override", {}))
          .merge(data.fetch("automatic", {}))
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

      # Deeply stringify keys of Array/Hash
      def stringify(result)
        JSON.parse(JSON.dump(result))
      end

      # ========================================================================
      # Interfacing with Inspec and Chef

      # Reach for Kitchen data and return its evaluated config
      # @todo DI
      def kitchen_provisioner_config
        require "binding_of_caller"
        kitchen = binding.callers.find { |b| b.frame_description == "verify" }.receiver

        kitchen.provisioner.send(:provided_config)
      end

      # Get plugin specific configuration
      def plugin_conf
        inspec_config.fetch_plugin_config("inspec-chef")
      end

      # Get plugin setting via environment, config file or default
      def fetch_plugin_setting(setting_name, default = nil)
        env_var_name = "INSPEC_CHEF_#{setting_name.upcase}"
        config_name = "chef_api_#{setting_name.downcase}"
        ENV[env_var_name] || plugin_conf[config_name] || default
      end

      # Get remote address for this scan from InSpec
      def scan_target
        target = inspec_config.final_options["target"]
        URI.parse(target)&.host
      end

      # Establish a Chef Server connection
      def connect_to_chef_server
        # From within TestKitchen we need no Chef Server connection
        if inside_testkitchen?
          logger.info "Running from TestKitchen, using provisioner settings instead of Chef Server"

        # Only connect once
        elsif !server_connected?
          @plugin_conf = inspec_config.fetch_plugin_config("inspec-chef")

          chef_endpoint = fetch_plugin_setting("endpoint")
          chef_client   = fetch_plugin_setting("client")
          chef_api_key  = fetch_plugin_setting("key")

          unless chef_endpoint && chef_client && chef_api_key
            raise "ERROR: Plugin inspec-chef needs configuration of chef endpoint, client name and api key."
          end

          # @todo: DI this
          @chef_server ||= ChefAPI::Connection.new(
            endpoint: chef_endpoint,
            client:   chef_client,
            key:      chef_api_key
          )

          logger.debug format("Connected to %s as client %s", chef_endpoint, chef_client)
        end
      end

      # Return if connection is established
      def server_connected?
        ! chef_server.nil?
      end

      # Low-level Chef search expression
      def get_search(index, expression)
        chef_server.search.query(index, expression, rows: 1).rows.first
      end

      # Retrieve a Databag item from Chef Server
      def get_databag_item(databag, item)
        unless inside_testkitchen?
          unless chef_server.data_bags.any? { |k| k.name == databag }
            raise format('Databag "%s" not found on Chef Infra Server', databag)
          end

          chef_server.data_bag_item.fetch(item, bag: databag).data
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
        logger.debug format("Automatic lookup of node name (IPv4 or hostname) returned: %s", result&.fetch("name") || "(nothing)")

        # Try EC2 lookup, if nothing found (assuming public IP)
        unless result
          query = "ec2_public_ipv4:%<address>s OR ec2_public_hostname:%<address>s"
          result = get_search(:node, format(query, address: ip_or_name))
          logger.debug format("Automatic lookup of node name (EC2 public IPv4 or hostname) returned: %s", result&.fetch("name"))
        end

        # This will fail for cases like trying to connect to IPv6, so it will need extension in the future

        result&.fetch("name") || raise(format("Unable too lookup remote Chef client name from %s", ip_or_name))
      end
    end
  end
end

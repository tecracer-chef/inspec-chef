require_relative "../helper.rb"

require "inspec-chef/input"

module ChefUnitTests
  class Helper < Minitest::Test
    attr_reader :plugin

    def setup
      @plugin = InspecPlugins::Chef::Input.new

      InspecPlugins::Chef::Input.send(:public, *plugin.private_methods)
    end

    ############################################################################
    # inside_testkitchen?

    def test_it_should_recognize_manual_invocation
      Kernel.send(:remove_const, :Kitchen)

      assert_equal false, plugin.inside_testkitchen?
    end

    def test_it_should_recognize_testkitchen
      Kernel.const_set "Kitchen", Class.new

      assert_equal true, plugin.inside_testkitchen?
    end

    ############################################################################
    # ip?

    def test_it_should_recognize_an_ip
      assert plugin.ip?("1.2.3.4")
    end

    def test_it_should_recognize_an_non_ip
      assert_equal false, plugin.ip?("1.2.3.")
      assert_equal false, plugin.ip?("hostname")
      assert_equal false, plugin.ip?("hostname.domain")
    end

    ############################################################################
    # fqdn?

    def test_it_should_recognize_an_fqdn
      assert plugin.fqdn?("hostname.domain")
    end

    def test_it_should_recognize_an_non_fqdn
      assert_equal false, plugin.fqdn?("1.2.3.4")
      assert_equal false, plugin.fqdn?("hostname")
    end

    ############################################################################
    # merge_attributes

    def test_it_should_merge_attributes_right
      assert_equal(
        { "a" => 1 },
        plugin.merge_attributes({ "default" => { "a" => 1 } })
      )
      assert_equal(
        { "a" => 1 },
        plugin.merge_attributes({ "normal" => { "a" => 1 } })
      )
      assert_equal(
        { "a" => 1 },
        plugin.merge_attributes({ "override" => { "a" => 1 } })
      )
      assert_equal(
        { "a" => 1 },
        plugin.merge_attributes({ "automatic" => { "a" => 1 } })
      )

      assert_equal(
        { "a" => 2 },
        plugin.merge_attributes({ "default" => { "a" => 1 }, "normal" => { "a" => 2 } })
      )
      assert_equal(
        { "a" => 2 },
        plugin.merge_attributes({ "default" => { "a" => 1 }, "override" => { "a" => 2 } })
      )
      assert_equal(
        { "a" => 2 },
        plugin.merge_attributes({ "default" => { "a" => 1 }, "automatic" => { "a" => 2 } })
      )
      assert_equal(
        { "a" => 2 },
        plugin.merge_attributes({ "normal" => { "a" => 1 }, "override" => { "a" => 2 } })
      )
      assert_equal(
        { "a" => 2 },
        plugin.merge_attributes({ "normal" => { "a" => 1 }, "automatic" => { "a" => 2 } })
      )
      assert_equal(
        { "a" => 2 },
        plugin.merge_attributes({ "override" => { "a" => 1 }, "automatic" => { "a" => 2 } })
      )
    end

    ############################################################################
    # valid_plugin_input?

    def test_it_should_recognize_valid_databag_inputs
      assert plugin.valid_plugin_input?("databag://configuration/database/key")
      assert plugin.valid_plugin_input?("databag://configuration/database/some/sub/key")
    end

    def test_it_should_recognize_valid_attribute_inputs
      # Explicit host
      assert plugin.valid_plugin_input?("node://hostname/attributes/ec2/public_ipv4")

      # Implicit host / automatic node detection
      assert plugin.valid_plugin_input?("node:///attributes/ec2/public_ipv4")
    end

    def test_it_should_ignore_mistyped_inputs
      # No key given
      assert_equal false, plugin.valid_plugin_input?("databag://configuration/database")

      # Forgot /attributes/
      assert_equal false, plugin.valid_plugin_input?("node://hostname/ec2/public_ipv4")
      assert_equal false, plugin.valid_plugin_input?("node:///ec2/public_ipv4")
    end

    def test_it_should_ignore_other_inputs
      assert_equal false, plugin.valid_plugin_input?("teststring")
    end

    ############################################################################
    # parse_input

    def test_it_should_parse_node_input_uris
      assert_equal(
        {
          type: :node,
          object: "hostname",
          item: "attributes",
          query: %w{key},
        },
        plugin.parse_input("node://hostname/attributes/key")
      )

      assert_equal(
        {
          type: :node,
          object: "hostname",
          item: "attributes",
          query: %w{sub key},
        },
        plugin.parse_input("node://hostname/attributes/sub/key")
      )

      # Auto node detection
      assert_equal(
        {
          type: :node,
          object: nil,
          item: "attributes",
          query: %w{sub key},
        },
        plugin.parse_input("node:///attributes/sub/key")
      )
    end

    def test_it_should_parse_databag_input_uris
      assert_equal(
        {
          type: :databag,
          object: "name",
          item: "item",
          query: %w{key},
        },
        plugin.parse_input("databag://name/item/key")
      )

      assert_equal(
        {
          type: :databag,
          object: "name",
          item: "item-name",
          query: %w{some sub key},
        },
        plugin.parse_input("databag://name/item-name/some/sub/key")
      )
    end

    ############################################################################
    # stringify (TODO)
  end
end

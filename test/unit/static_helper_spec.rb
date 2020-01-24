require_relative "../helper.rb"

require "inspec-chef/input"

class Minitest::Spec
  before :each do
    # Make private methods accessible by redefining them as public
    InspecPlugins::Chef::Input.send(:public, *InspecPlugins::Chef::Input.private_instance_methods)
  end
end

module ChefUnitTests
  class StaticHelpers < Minitest::Test
    def plugin
      InspecPlugins::Chef::Input
    end

    def test_it_should_recognize_valid_databag_inputs
      assert_equal(plugin.valid_plugin_input?('databag://configuration/database/key'), true)
      assert_equal(plugin.valid_plugin_input?('databag://configuration/database/some/sub/key'), true)
    end

    def test_it_should_recognize_valid_attribute_inputs
      assert_equal(plugin.valid_plugin_input?('node://hostname/attributes/ec2/public_ipv4'), true)
      assert_equal(plugin.valid_plugin_input?('node:///attributes/ec2/public_ipv4'), true)
    end

    def test_it_should_ignore_mistyped_inputs
      # No key given
      assert_equal(plugin.valid_plugin_input?('databag://configuration/database'), false)

      # Forgot /attributes/
      assert_equal(plugin.valid_plugin_input?('node://hostname/ec2/public_ipv4'), false)
    end

    def test_it_should_ignore_other_inputs
      assert_equal(plugin.valid_plugin_input?('teststring'), false)
    end

    def test_it_should_recognize_an_ip
      assert_equal(plugin.ip?('1.2.3.4'), true)

      assert_equal(plugin.ip?('1.2.3.'), false)
      assert_equal(plugin.ip?('hostname'), false)
      assert_equal(plugin.ip?('hostname.domain'), false)
    end

    def test_it_should_recognize_an_fqdn
      assert_equal(plugin.fqdn?('hostname.domain'), true)

      assert_equal(plugin.fqdn?('1.2.3.4'), false)
      assert_equal(plugin.fqdn?('hostname'), false)
    end

    def test_it_should_parse_databag_input_uris
      assert_equal(
        plugin.parse_input('databag://name/item/key'),
        {
          type: :databag,
          object: 'name',
          item: 'item',
          query: %w[key]
        }
      )

      assert_equal(
        plugin.parse_input('databag://name/item-name/some/sub/key'),
        {
          type: :databag,
          object: 'name',
          item: 'item-name',
          query: %w[some sub key]
        }
      )
    end

    def test_it_should_parse_node_input_uris
      assert_equal(
        plugin.parse_input('node://hostname/attributes/key'),
        {
          type: :node,
          object: 'hostname',
          item: 'attributes',
          query: %w[key]
        }
      )

      assert_equal(
        plugin.parse_input('node://hostname/attributes/sub/key'),
        {
          type: :node,
          object: 'hostname',
          item: 'attributes',
          query: %w[sub key]
        }
      )

      # Auto node detection
      assert_equal(
        plugin.parse_input('node:///attributes/sub/key'),
        {
          type: :node,
          object: nil,
          item: 'attributes',
          query: %w[sub key]
        }
      )
    end

    def test_it_should_parse_autonode_input_uris
      # need to
    end
  end
end

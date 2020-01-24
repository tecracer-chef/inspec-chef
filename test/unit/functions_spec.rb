require_relative "../helper.rb"

require "inspec-chef/input"

module ChefUnitTests
  class Functions < Minitest::Test
    attr_reader :plugin
    
    def setup
      @plugin = InspecPlugins::Chef::Input.new
      InspecPlugins::Chef::Input.send(:public, *plugin.private_methods)
    end

    ############################################################################
    # scan_target

    def test_it_should_get_the_right_scan_target
      inspec_mock = Minitest::Mock.new
      def inspec_mock.final_options
        { "target" => "ssh://user:pass@123.456.789.012/" }
      end

      plugin.inspec_config = inspec_mock

      assert_equal "123.456.789.012", plugin.scan_target
    end
  end
end

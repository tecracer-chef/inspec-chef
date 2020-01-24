require_relative "../helper.rb"

require "inspec-chef/input"

module ChefUnitTests
  class Helpers < Minitest::Test
    def test_it_should_get_the_right_scan_target
      inspec_mock = Minitest::Mock.new
      def inspec_mock.final_options
        { "target" => "ssh://user:pass@123.456.789.012/" }
      end

      plugin = InspecPlugins::Chef::Input.new
      plugin.inspec_config = inspec_mock

      assert_equal "123.456.789.012", plugin.send(:scan_target)
    end
  end
end

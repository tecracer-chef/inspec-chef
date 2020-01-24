require_relative "../helper.rb"

require "inspec-chef/version"

module InspecChefUnitTests
  class Version < Minitest::Test
    def test_should_have_a_version_constant_defined
      assert_kind_of(String, InspecPlugins::Chef::VERSION)
    end
  end
end

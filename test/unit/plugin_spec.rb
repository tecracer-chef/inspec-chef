require_relative "../helper.rb"

require "inspec-chef/plugin"

module InspecChefUnitTests
  class Plugin < Minitest::Test
    def setup
      @plugin_name = :'inspec-chef'
      @registry = ::Inspec::Plugin::V2::Registry.instance
      @status = @registry[@plugin_name]
    end

    def test_it_should_be_registered
      assert @registry.known_plugin?(@plugin_name)
    end

    def test_it_should_be_an_api_v2_plugin
      assert_equal 2, @status.api_generation
    end

    def test_it_should_include_a_input_activator_hook
      assert_includes @status.plugin_types, :input
    end
  end
end

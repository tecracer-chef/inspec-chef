# encoding: UTF-8

# Plugin Definition file
# The purpose of this file is to declare to InSpec what plugin_types (capabilities)
# are included in this plugin, and provide hooks that will load them as needed.

# It is important that this file load successfully and *quickly*.
# Your plugin's functionality may never be used on this InSpec run; so we keep things
# fast and light by only loading heavy things when they are needed.

require "inspec-chef/version"
module InspecPlugins
  module Chef
    class Plugin < ::Inspec.plugin(2)
      # Internal machine name of the plugin. InSpec will use this in errors, etc.
      plugin_name :'inspec-chef'

      # Define an Input plugin type.
      input :chef do
        require_relative "input.rb"
        InspecPlugins::Chef::Input
      end
    end
  end
end

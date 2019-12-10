# inspec-chef

Input plugin for InSpec to access Chef Server data within profiles

## Use Case

Some systems rely on Chef Databags or Attributes to be provisioned in the right
state, triggering specific configuration which is then hard to verify using
InSpec. For example, one system could have an SQL Server 2012 installed
while the other has SQL Server 2019. While both might perform an identical
role, the InSpec tests have to distinguish between both and get some
information on the characteristics to test.

As the configuration information is already present in those constructs,
it makes little sense to manually configure separate profiles.

## Installation

Simply execute `inspec plugin install inspec-chef`, which will get
the plugin from RubyGems and install/register it with InSpec.

You can verify successful installation via `inspec plugin list`

## Configuration

Each plugin option may be set either as an environment variable, or as a plugin
option in your Chef InSpec configuration file at ~/.inspec/config.json. For
example, to set the chef server information in the config file, lay out the
config file as follows:

```json
{
  "version": "1.2",
  "plugins":{
    "inspec-chef":{
      "chef_api_endpoint": "https://chef.example.com/organizations/testing",
      "chef_api_client":   "workstation",
      "chef_api_key":      "/etc/chef/workstation.pem"
    }
  }
}
```

Config file option names are always lowercase.

This plugin supports the following options:

| Environment Variable | config.json Option | Description |
| - | - | - |
| INSPEC_CHEF_ENDPOINT | chef_api_endpoint | The URL of your Chef server, including the organization |
| INSPEC_CHEF_CLIENT   | chef_api_client   | The name of the client of the Chef server to connect as |
| INSPEC_CHEF_KEY      | chef_api_key      | Path to the private certificate identifying the node |

## Usage

When this plugin is loaded, you can use databag items as inputs:

```ruby
hostname = input('databag://databagname/item#JMESPath.Search.Query')

describe host(hostname, port: 80, protocol: 'tcp') do
  it { should be_reachable }
end
```

In the same way, you can also add attributes of arbitary nodes:

```ruby
hostname = input('node://nodename/attribute#JMESPath.Search.Query')

describe host(hostname, port: 80, protocol: 'tcp') do
  it { should be_reachable }
end
```

InSpec will go through all loaded input plugins by priority and determine the value.

Keep in mind, that the node executing your InSpec runs needs to be
registered with the chef server to be able to access the data. Lookup
is __not__ done on the clients tested, but the executing workstation.

## Example

With this plugin, the input names consist of the name of the databag,
the item and a JMESPath query for getting a specific value within an item.
This way, you can have a databag "configuration" with an item "database" like:

```json
{
  "SQL": {
    "Type": "SQL2019"
  }
}
```

and then use `input('databag://configuration/database#SQL.Type')` to get the "SQL2019" value out.
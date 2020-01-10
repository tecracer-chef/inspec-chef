#------------------------------------------------------------------#
#                    Code Style Tasks
#------------------------------------------------------------------#
require "bump/tasks"
require "chefstyle"
require "rubocop/rake_task"
require "rspec/core/rake_task"
require "bundler/gem_tasks"

RuboCop::RakeTask.new(:lint)

# Remove unneeded tasks
Rake::Task["release"].clear

# We run tests by default
task default: :test
task gem: :build

#
# Install all tasks found in tasks folder
#
# See .rake files there for complete documentation.
#
Dir["tasks/*.rake"]&.each do |taskfile|
  load taskfile
end

#------------------------------------------------------------------#
#                    Gem Packaging Tasks
#------------------------------------------------------------------#
begin
  require "bundler"
  Bundler::GemHelper.install_tasks
rescue LoadError
  # no bundler available
end

#------------------------------------------------------------------#
#                    Linter Tasks
#------------------------------------------------------------------#

begin
  require "chefstyle"
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:lint) do |task|
    task.options += ["--display-cop-names", "--no-color", "--parallel"]
  end

rescue LoadError
  puts "rubocop is not available. Install the rubocop gem to run the lint tests."
end

#------------------------------------------------------------------#
#                    Test Runner Tasks
#------------------------------------------------------------------#
require "rake/testtask"

namespace(:test) do
  # This task template will make a task named 'test', and run
  # the tests that it finds.
  # Here, we split up the tests a bit, for the convenience
  # of the developer.
  desc "Run unit tests, to probe internal correctness"
  Rake::TestTask.new(:unit) do |task|
    task.libs << "test"
    task.pattern = "test/unit/*_spec.rb"
    task.warning = false
  end
end

#------------------------------------------------------------------#
#                              Bump Tasks
#------------------------------------------------------------------#
begin
  require "bump/tasks"
  Bundler::GemHelper.install_tasks
rescue LoadError
  # no bundler available
end

desc "Run all tests"
task test: %i{test:unit}

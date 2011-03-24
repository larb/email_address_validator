require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/rdoctask'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) 
task :default => :spec

desc "Rebuild the parsers"
task "parser" do
  sh "kpeg -s -o lib/email_address_validator/rfc822-parser.rb  -f grammars/rfc822.kpeg"
  sh "kpeg -s -o lib/email_address_validator/rfc2822-parser.rb -f grammars/rfc2822.kpeg"
  sh "kpeg -s -o lib/email_address_validator/domain-parser.rb  -f grammars/domain.kpeg"
end

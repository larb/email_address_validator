
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

task "parser" do
  sh "kpeg -s -o lib/email_address_validator/rfc822-parser.rb  -f grammars/rfc822.kpeg"
  sh "kpeg -s -o lib/email_address_validator/rfc2822-parser.rb -f grammars/rfc2822.kpeg"
  sh "kpeg -s -o lib/email_address_validator/domain-parser.rb  -f grammars/domain.kpeg"
end

Bones {
  name     'rfc-822-validator'
  authors  'Evan Phoenix, Andrew Cholakian'
  email    'andrew@andrewvc.com'
  url      'https://github.com/andrewvc/rfc-822'
}



begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

task "parser" do
  sh "kpeg -s -o lib/rfc-822/parser.rb -f email.kpeg"
  sh "kpeg -s -o lib/rfc-822/parser2822.rb -f rfc2822.kpeg"
end

Bones {
  name     'rfc-822'
  authors  'FIXME (who is writing this software)'
  email    'FIXME (your e-mail)'
  url      'FIXME (project homepage)'
}


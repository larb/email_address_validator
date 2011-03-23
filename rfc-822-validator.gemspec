# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rfc-822-validator}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Evan Phoenix, Andrew Cholakian"]
  s.date = %q{2011-03-22}
  s.default_executable = %q{rfc-822}
  s.description = %q{Implementation of RFC-822}
  s.email = %q{andrew@andrewvc.com}
  s.executables = ["rfc-822"]
  s.extra_rdoc_files = ["History.txt", "bin/rfc-822"]
  s.files = [".README.md.swp", ".bnsignore", "History.txt", "README.md", "Rakefile", "bin/rfc-822", "email.kpeg", "lib/rfc-822.rb", "lib/rfc-822/parser.rb", "rfc-822-validator.gemspec", "spec/.rfc-822_spec.rb.swp", "spec/rfc-822_spec.rb", "spec/spec_helper.rb", "test/test_rfc-822.rb", "version.txt"]
  s.homepage = %q{https://github.com/andrewvc/rfc-822}
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rfc-822-validator}
  s.rubygems_version = %q{1.6.0}
  s.summary = %q{Implementation of RFC-822}
  s.test_files = ["test/test_rfc-822.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bones>, [">= 3.6.5"])
    else
      s.add_dependency(%q<bones>, [">= 3.6.5"])
    end
  else
    s.add_dependency(%q<bones>, [">= 3.6.5"])
  end
end

# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "email_address_validator/version"

Gem::Specification.new do |s|
  s.name        = "email_address_validator"
  s.version     = EmailAddressValidator::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Evan Phoenix", "Andrew Cholakian"]
  s.email       = ["andrew@andrewvc.com"]
  s.homepage    = "https://github.com/andrewvc/rfc-822"
  s.summary     = %q{RFC 2822/822 Email Address Parsing.}
  s.description = %q{RFC Compliant Email Address Parsing using the KPEG grammars.}
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]

  s.rubyforge_project = "email_address_validator"

  s.add_development_dependency "rspec", ">= 2.4.0"
  s.add_development_dependency "kpeg",  ">= 0.7.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end


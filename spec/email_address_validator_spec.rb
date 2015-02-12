
require File.join(File.dirname(__FILE__), %w[spec_helper])

describe EmailAddressValidator do
  VALID_COMMON   =
            ["simple@example.com", "\"Abc\@def\"@example.com",
             "\"Fred Bloggs\"@example.com", "\"Joe\\Blow\"@example.com",
             "\"Abc@def\"@example.com", "customer/department=shipping@example.com",
             "$A12345@example.com", "!def!xyz%abc@example.com",
             "\"Chris Jones\" <c@a.test>",
             "Group:\"Chris Jones\" <c@a.test>,joe@where.test,John <jdoe@one.test>;", 
             "A Group:\"Chris Jones\" <c@a.test>,joe@where.test,John <jdoe@one.test>;", 
             "l3tt3rsAndNumb3rs@domain.com", "has-dash@domain.com",
             "hasApostrophe.o'leary@domain.org", "uncommonTLD@domain.museum",
             "lettersInDomain@911.com", "underscore_inLocal@domain.net",
             "subdomain@sub.domain.com", "local@dash-inDomain.com",
             "dot.inLocal@foo.com", "a@singleLetterLocal.org",
             "singleLetterDomain@x.org", "&*=?^+{}'~@validCharsInLocal.net",
             "foor@bar.newTLD", "domainStartsWithDash@-domain.com",
             "local@SecondLevelDomainNamesValidEvenIfTheyAreLongerThan64Charactersss.org",
             "ipsaredomains@127.0.0.1.26", "domainEndsWithDash@domain-.com",
             "numbersInTLD@domain.c0m", "IPInsteadOfDomain@127.0.0.1",

             "shortipv6@[::1]", "fullipv6@[2001:0DB7:1982:A098:2001:0DB7:1982:A098]",
             "toomanyoctets@[2001:0DB7:1982:A098:2001:0DB7:1982:A098:8991]",
             "garbageipv6@[nthueonthueonhurc]",
             "missingDot@com"
  ]

  VALID_DOMAIN_COMMON = %w!evan@foo.com evan@com evan@blah.foo.com
                           evan@foo-bar.com evan@foo3bar.com evan@foo-3bar.com
                           evan@3foo-4bar.com!

  INVALID_DOMAIN_COMMON = %w!evan@-foo.com evan@foo-.com evan@foo.c$m evan@-
                             evan@thisismorethan63octetssoitwillfailbecauserfc1123sayssoandwedowhatitsays-bar.com
                             evan@thisismorethan255octetssoitwillfailbecauserfc1123sayssoandwedowhatitsays.thisismorethan255octetssoitwillfailbecauserfc1123sayssoandwedowhatitsays.thisismorethan255octetssoitwillfailbecauserfc1123sayssoandwedowhatitsays.thisismorethan255octetssoitwillfailbecauserfc1123sayssoandwedowhatitsays!

  INVALID_COMMON =
            ["NotAnEmail", "@NotAnEmail", "nodomain@", "missingDomain@.com",
             "@missingLocal.org", "missingatSign.net",
             "two@@signs.com", "colonButNoPort@127.0.0.1:",
             ".localStartsWithDot@domain.com",
             "localEndsWithDot.@domain.com", "two..consecutiveDots@domain.com",
             "missingTLD@domain.",
             "! \"#\$%(),/;<>[]`|@CharsInLocal.org",
             "IPAndPort@127.0.0.1:25",
             "CharsInDomain@! \"#\$%(),/;<>_[]`|.org",
  ]

  VALID   = VALID_COMMON  + [ "c@(Chris's host.)public.example" ]

  VALID_ADDRSPEC = ["l3tt3rsAndNumb3rs@domain.com", "has-dash@domain.com"]

  INVALID = INVALID_COMMON

  VALID.each do |addr|
    it "should recognize <#{addr}> as valid" do
      EmailAddressValidator.validate_822(addr).should be_true
    end
  end

  INVALID.each do |addr|
    it "should recognize <#{addr}> as invalid" do
      EmailAddressValidator.validate_822(addr).should be_false
    end
  end

  VALID_ADDRSPEC.each do |addr|
    it "should recognize <#{addr}> as valid" do
      EmailAddressValidator.validate_822_addr(addr).should be_true
    end
  end

  VALID_DOMAIN_COMMON.each do |addr|
    it "should validate the domain of <#{addr}> as valid" do
      EmailAddressValidator.validate_822(addr, true).should be_true
    end
  end

  INVALID_DOMAIN_COMMON.each do |addr|
    it "should validate the domain of <#{addr}> as invalid" do
      EmailAddressValidator.validate_822(addr, true).should be_false
    end
  end

  VALID_MODERN = VALID_COMMON

  INVALID_MODERN = INVALID_COMMON

  VALID_MODERN.each do |addr|
    it "should recognize modern <#{addr}> as valid" do
      EmailAddressValidator.validate_2822_addr(addr).should be_true
      EmailAddressValidator.validate_addr(addr).should be_true
    end
  end

  INVALID_MODERN.each do |addr|
    it "should recognize modern <#{addr}> as invalid" do
      EmailAddressValidator.validate_2822_addr(addr).should be_false
      EmailAddressValidator.validate_addr(addr).should be_false
    end
  end

  VALID_ADDRSPEC.each do |addr|
    it "should recognize modern <#{addr}> as valid" do
      EmailAddressValidator.validate_2822_addr(addr).should be_true
      EmailAddressValidator.validate_addr(addr).should be_true
    end
  end

  VALID_DOMAIN_COMMON.each do |addr|
    it "should validate the domain of <#{addr}> as valid" do
      EmailAddressValidator.validate_2822(addr, true).should be_true
      EmailAddressValidator.validate(addr, true).should be_true
    end
  end

  INVALID_DOMAIN_COMMON.each do |addr|
    it "should validate the domain of <#{addr}> as invalid" do
      EmailAddressValidator.validate_822(addr, true).should be_false
    end
  end

end

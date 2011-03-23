
require File.join(File.dirname(__FILE__), %w[spec_helper])

describe RFC822 do
  VALID   = ["simple@example.com", "\"Abc\@def\"@example.com", 
             "\"Fred Bloggs\"@example.com", "\"Joe\\Blow\"@example.com",
             "\"Abc@def\"@example.com", "customer/department=shipping@example.com",
             "$A12345@example.com", "!def!xyz%abc@example.com",
             "c@(Chris's host.)public.example",
             "A Group:Chris Jones <c@a.test>,joe@where.test,John <jdoe@one.test>;", 
             "l3tt3rsAndNumb3rs@domain.com", "has-dash@domain.com",
             "hasApostrophe.o'leary@domain.org", "uncommonTLD@domain.museum",
             "lettersInDomain@911.com", "underscore_inLocal@domain.net",
             "IPInsteadOfDomain@127.0.0.1", "IPAndPort@127.0.0.1:25",
             "subdomain@sub.domain.com", "local@dash-inDomain.com",
             "dot.inLocal@foo.com", "a@singleLetterLocal.org",
             "shortipv6@[::1]", "fullipv6@[2001:0DB7:1982:A098:2001:0DB7:1982:A098]"
             "singleLetterDomain@x.org", "&*=?^+{}'~@validCharsInLocal.net",
             "foor@bar.newTLD"
  ]

  INVALID = ["NotAnEmail", "@NotAnEmail", "nodomain@", "missingDomain@.com",
             "@missingLocal.org", "missingatSign.net", "missingDot@com",
             "two@@signs.com", "colonButNoPort@127.0.0.1:", 
             "someone-else@127.0.0.1.26", ".localStartsWithDot@domain.com",
             "localEndsWithDot.@domain.com", "two..consecutiveDots@domain.com",
             "domainStartsWithDash@-domain.com", "domainEndsWithDash@domain-.com",
             "numbersInTLD@domain.c0m", "missingTLD@domain.",
             "! \"#\$%(),/;<>[]`|@CharsInLocal.org",
             "CharsInDomain@! \"#\$%(),/;<>_[]`|.org",
             "toomanyoctets@[2001:0DB7:1982:A098:2001:0DB7:1982:A098:8991]",
             "garbageipv6@[nthueonthueonhurc]",
             "local@SecondLevelDomainNamesAreInvalidIfTheyAreLongerThan64Charactersss.org" 
  ]
  
  VALID.each do |addr|
    it "should recognize <#{addr}> as valid" do
      RFC822.validate(addr).should be_true
    end
  end

  INVALID.each do |addr|
    it "should recognize <#{addr}> as invalid" do
      RFC822.validate(addr).should be_false
    end
  end
end

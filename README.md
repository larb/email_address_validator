# EmailAddressValidator #

Implementation of RFCs 2822 and 822 for email address validation, and 1123 for domain validation.

## Description ##

Parsing email addresses is not easy, and most regex based approaches deviate from the RFCs. This library is based off the actual grammars in the RFCs, allowing it to achieve greater accuracy.

This may mean that this library is more permissive than you desire, as the RFCs support syntax that many will find undesirable. To accomodate this, there are a few options users can set to achieve more practical results.

The two man things to know are that:

1. What most people desire from a validator is to match only the addr_spec portion of the grammars, as this keeps certain weird addresses, such as RFC groups excluded.
2. RFCs 822/2822 do not require valid domains, essentially requiring little more than dotted strings. This library provides additional RFC-1123 Parsing to ensure that a valid domain has been passed in.

## Examples ##

Validate only the addr_spec portion of an address as per RFC-2822. Additionally, validate the domain of the address as per RFC-1123. This is what most people probably want:

    EmailAddressValidator.validate_addr('example@example.net',true)

Validate against the full grammar for RFC-2822, without checking the domain.

    EmailAddressValidator.validate('example@example.net', false)

Validate against the addr_spec portion of RFC-822

    EmailAddressValidator.validate_822_addr('example@example.net')

Validate against the full grammar for RFC-822

    EmailAddressValidator.validate_822('example@example.net')

Validate a domain per RFC-1123
    
    EmailAddressValidator.validate_domain('example.net')

## Additional notes on the RFCs ##

RFC 2822 removes a lot of the cruft that 822 carries with it, unless you have a good reason, you likely want to stay away from RFC 822.

A few fun things came up researching this library: 

* RFCs 2822/822 do not validate domains properly.
* RFCs 2822/822 support groups, multiple labeled lists of addresses such as `MyGroup: "John Higgins" <john@example.net>, mark mark@example.net;`
* RFC 822 supports routes, a sequence of mailservers the message is supposed to travel, such as `test@mymailserver@othermailserver.com`
* RFCs 2822/822 support double quoted strings as the local part of an address, with crazy chars in them, such as `"my@funky$address"@example.net`
* RFCs 2822/822 support phrases before angle bracketed addresses so the entirety of the string `"Test" <test@example.net>` is valid. This is why you probably only want to validate the addr_spec portion.

## Further Reading ##

[RFC-2822](http://www.ietf.org/rfc/rfc2822.txt)
[RFC-822](http://www.ietf.org/rfc/rfc0822.txt)
[RFC-1123](http://www.ietf.org/rfc/rfc1123.txt)

## Authors ##

Evan Phoenix [evanphx](http://github.com/evanphx)
Andrew Cholakian [andrewvc](http://github.com/andrewvc)

## License ##
 
(The MIT License) FIXME (different license?)

Copyright (c) 2011 FIXME (author's name)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

rfc-2822
===========

Implementation of RFC-2822

Features
--------

Validates RFC-2822 Addresses

More usefully, it validates the addr_spec portion of the addresses

Examples
--------

# Validate an address as per the RFC
    RFC822.validate('example@example.net')

# Validate an address per the addr_spec portion of the RFC
# This is what most people actually expect in an address
    RFC822.validate_addr('example@example.net')

A note on the RFC
-----------------
RFC 822 has some oddities, it does things most people don't expect, such as

* It does not validate domains
* It supports groups, multiple labeled lists of addresses. ex: MyGroup: "John Higgins" <john@example.net>, mark mark@example.net;
* It supports routes, a sequence of mailservers the message is supposed to travel. ex: test@mymailserver@othermailserver.com
* It support sdouble quoted strings as the local part of an address, with crazy chars in them. ex: "my@funkyaddress"@example.net
* It supports phrases before angle bracketed addresses. ex: "Test" <test@example.net>.


Authors
------

Evan Phoenix (evanphx)
Andrew Cholakian (andrewvc)

License
-------

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

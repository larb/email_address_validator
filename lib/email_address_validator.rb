module EmailAddressValidator
  # :stopdoc:
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR
  # :startdoc:

  # Returns the library path for the module. If any arguments are given,
  # they will be joined to the end of the libray path using
  # <tt>File.join</tt>.
  #
  def self.libpath( *args )
    rv =  args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
    if block_given?
      begin
        $LOAD_PATH.unshift LIBPATH
        rv = yield
      ensure
        $LOAD_PATH.shift
      end
    end
    return rv
  end

  # Returns the lpath for the module. If any arguments are given,
  # they will be joined to the end of the path using
  # <tt>File.join</tt>.
  #
  def self.path( *args )
    rv = args.empty? ? PATH : ::File.join(PATH, args.flatten)
    if block_given?
      begin
        $LOAD_PATH.unshift PATH
        rv = yield
      ensure
        $LOAD_PATH.shift
      end
    end
    return rv
  end

  # Utility method used to require all files ending in .rb that lie in the
  # directory below this file that has the same name as the filename passed
  # in. Optionally, a specific _directory_ name can be passed in such that
  # the _filename_ does not have to be equivalent to the directory.
  #
  def self.require_all_libs_relative_to( fname, dir = nil )
    dir ||= ::File.basename(fname, '.*')
    search_me = ::File.expand_path(
        ::File.join(::File.dirname(fname), dir, '**', '*.rb'))

    Dir.glob(search_me).sort.each {|rb| require rb}
  end
  
  # Shorthand for +EmailAddressParser.validate_2822_addr
  def self.validate_addr(addr, validate_domain=false); self.validate_2822; end

  # Validates +addr+ against the addr_spec portion of RFC 2822.
  # This is what most people actually want out of an email validator
  # You very well may want to set validate_domain to true as well,
  # as RFC2822 doesn't explicitly require valid domains
  def self.validate_2822_addr(addr, validate_domain=false)
    parser = RFC2822Parser.new(addr, "only_addr_spec")
    parser.validate_domain = validate_domain
    parser.parse
  end

  # Shorthand for +EmailAddressParser.validate_2822
  def self.validate(addr, validate_domain=false); self.validate_2822; end

  # Validates an email address according to RFC 2822
  # This validates addresses against the full spec, which
  # may not be what you want. 
  def self.validate_2822(addr, validate_domain=false)
    parser = RFC2822Parser.new(addr)
    parser.validate_domain = validate_domain
    parser.parse
  end

  # Validates legacy address according to RFC 822, the original
  # email grammar.
  def self.validate_822(addr, validate_domain=false)
    parser = RFC822Parser.new(addr)
    parser.validate_domain = validate_domain
    parser.parse
  end

  # Validates only the addr_spec portion an address according to RFC 822
  def self.validate_822_addr(addr, validate_domain=false)
    parser = RFC822Parser.new(addr, "only_addr_spec")
    parser.validate_domain = validate_domain
    parser.parse
  end

  # Validates a domain name
  def self.validate_domain(domain)
    parser = DomainParser.new(addr)
    parser.parse
  end

end

EmailAddressValidator.require_all_libs_relative_to(__FILE__)

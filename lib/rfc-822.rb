
module RFC822

  # :stopdoc:
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR
  VERSION = ::File.read(PATH + 'version.txt').strip
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


  def self.validate(addr, validate_domain=false)
    parser = Parser.new(addr)
    parser.validate_domain = validate_domain
    parser.parse
  end

  def self.validate_addr(addr, validate_domain=false)
    parser = Parser.new(addr, "only_addr_spec")
    parser.validate_domain = validate_domain
    parser.parse
  end

  def self.validate_modern(addr, validate_domain=false)
    parser = Parser2822.new(addr)
    parser.validate_domain = validate_domain
    parser.parse
  end

  def self.validate_modern_addr(addr, validate_domain=false)
    parser = Parser2822.new(addr, "only_addr_spec")
    parser.validate_domain = validate_domain
    parser.parse
  end

  def self.validate_domain(domain)
    parser = DomainParser.new(addr)
    parser.parse
  end

end  # module RFC822

RFC822.require_all_libs_relative_to(__FILE__)


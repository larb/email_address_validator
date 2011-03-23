class RFC822::Parser
# STANDALONE START
    def setup_parser(str, debug=false)
      @string = str
      @pos = 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @failed_rule = nil
      @failing_rule_offset = -1

      setup_foreign_grammar
    end

    def setup_foreign_grammar
    end

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    #
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end

    attr_reader :string
    attr_reader :result, :failing_rule_offset
    attr_accessor :pos

    # STANDALONE START
    def current_column(target=pos)
      if c = string.rindex("\n", target-1)
        return target - c - 1
      end

      target + 1
    end

    def current_line(target=pos)
      cur_offset = 0
      cur_line = 0

      string.each_line do |line|
        cur_line += 1
        cur_offset += line.size
        return cur_line if cur_offset >= target
      end

      -1
    end

    def lines
      lines = []
      string.each_line { |l| lines << l }
      lines
    end

    #

    def get_text(start)
      @string[start..@pos-1]
    end

    def show_pos
      width = 10
      if @pos < width
        "#{@pos} (\"#{@string[0,@pos]}\" @ \"#{@string[@pos,width]}\")"
      else
        "#{@pos} (\"... #{@string[@pos - width, width]}\" @ \"#{@string[@pos,width]}\")"
      end
    end

    def failure_info
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "line #{l}, column #{c}: failed rule '#{info.name}' = '#{info.rendered}'"
      else
        "line #{l}, column #{c}: failed rule '#{@failed_rule}'"
      end
    end

    def failure_caret
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      line = lines[l-1]
      "#{line}\n#{' ' * (c - 1)}^"
    end

    def failure_character
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset
      lines[l-1][c-1, 1]
    end

    def failure_oneline
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      char = lines[l-1][c-1, 1]

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "@#{l}:#{c} failed rule '#{info.name}', got '#{char}'"
      else
        "@#{l}:#{c} failed rule '#{@failed_rule}', got '#{char}'"
      end
    end

    class ParseError < RuntimeError
    end

    def raise_error
      raise ParseError, failure_oneline
    end

    def show_error(io=STDOUT)
      error_pos = @failing_rule_offset
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "On line #{line_no}, column #{col_no}:"

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        io.puts "Failed to match '#{info.rendered}' (rule '#{info.name}')"
      else
        io.puts "Failed to match rule '#{@failed_rule}'"
      end

      io.puts "Got: #{string[error_pos,1].inspect}"
      line = lines[line_no-1]
      io.puts "=> #{line}"
      io.print(" " * (col_no + 3))
      io.puts "^"
    end

    def set_failed_rule(name)
      if @pos > @failing_rule_offset
        @failed_rule = name
        @failing_rule_offset = @pos
      end
    end

    attr_reader :failed_rule

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def scan(reg)
      if m = reg.match(@string[@pos..-1])
        width = m.end(0)
        @pos += width
        return true
      end

      return nil
    end

    if "".respond_to? :getbyte
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string.getbyte @pos
        @pos += 1
        s
      end
    else
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string[@pos]
        @pos += 1
        s
      end
    end

    def parse(rule=nil)
      if !rule
        _root ? true : false
      else
        # This is not shared with code_generator.rb so this can be standalone
        method = rule.gsub("-","_hyphen_")
        __send__("_#{method}") ? true : false
      end
    end

    class LeftRecursive
      def initialize(detected=false)
        @detected = detected
      end

      attr_accessor :detected
    end

    class MemoEntry
      def initialize(ans, pos)
        @ans = ans
        @pos = pos
        @uses = 1
        @result = nil
      end

      attr_reader :ans, :pos, :uses, :result

      def inc!
        @uses += 1
      end

      def move!(ans, pos, result)
        @ans = ans
        @pos = pos
        @result = result
      end
    end

    def external_invoke(other, rule, *args)
      old_pos = @pos
      old_string = @string

      @pos = other.pos
      @string = other.string

      begin
        if val = __send__(rule, *args)
          other.pos = @pos
        else
          other.set_failed_rule "#{self.class}##{rule}"
        end
        val
      ensure
        @pos = old_pos
        @string = old_string
      end
    end

    def apply(rule)
      if m = @memoizations[rule][@pos]
        m.inc!

        prev = @pos
        @pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ rule

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr.detected
          return grow_lr(rule, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def grow_lr(rule, start_pos, m)
      while true
        @pos = start_pos
        @result = m.result

        ans = __send__ rule
        return nil unless ans

        break if @pos <= m.pos

        m.move! ans, @pos, @result
      end

      @result = m.result
      @pos = m.pos
      return m.ans
    end

    class RuleInfo
      def initialize(name, rendered)
        @name = name
        @rendered = rendered
      end

      attr_reader :name, :rendered
    end

    def self.rule_info(name, rendered)
      RuleInfo.new(name, rendered)
    end

    #
  def setup_foreign_grammar; end

  # HTAB = /\x09/
  def _HTAB
    _tmp = scan(/\A(?-mix:\x09)/)
    set_failed_rule :_HTAB unless _tmp
    return _tmp
  end

  # LF = /\x0A/
  def _LF
    _tmp = scan(/\A(?-mix:\x0A)/)
    set_failed_rule :_LF unless _tmp
    return _tmp
  end

  # CR = /\x0D/
  def _CR
    _tmp = scan(/\A(?-mix:\x0D)/)
    set_failed_rule :_CR unless _tmp
    return _tmp
  end

  # SPACE = " "
  def _SPACE
    _tmp = match_string(" ")
    set_failed_rule :_SPACE unless _tmp
    return _tmp
  end

  # - = SPACE*
  def __hyphen_
    while true
    _tmp = apply(:_SPACE)
    break unless _tmp
    end
    _tmp = true
    set_failed_rule :__hyphen_ unless _tmp
    return _tmp
  end

  # AT = "@"
  def _AT
    _tmp = match_string("@")
    set_failed_rule :_AT unless _tmp
    return _tmp
  end

  # LWSP_char = (SPACE | HTAB)
  def _LWSP_char

    _save = self.pos
    while true # choice
    _tmp = apply(:_SPACE)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_HTAB)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_LWSP_char unless _tmp
    return _tmp
  end

  # CHAR = /[\x00-\x7f]/
  def _CHAR
    _tmp = scan(/\A(?-mix:[\x00-\x7f])/)
    set_failed_rule :_CHAR unless _tmp
    return _tmp
  end

  # CTL = /[\x00-\x1f\x7f]/
  def _CTL
    _tmp = scan(/\A(?-mix:[\x00-\x1f\x7f])/)
    set_failed_rule :_CTL unless _tmp
    return _tmp
  end

  # special = /[\]()<>@,;:\\".\[]/
  def _special
    _tmp = scan(/\A(?-mix:[\]()<>@,;:\\".\[])/)
    set_failed_rule :_special unless _tmp
    return _tmp
  end

  # CRLF = CR LF
  def _CRLF

    _save = self.pos
    while true # sequence
    _tmp = apply(:_CR)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_LF)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_CRLF unless _tmp
    return _tmp
  end

  # linear_white_space = (CRLF? LWSP_char)+
  def _linear_white_space
    _save = self.pos

    _save1 = self.pos
    while true # sequence
    _save2 = self.pos
    _tmp = apply(:_CRLF)
    unless _tmp
      _tmp = true
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:_LWSP_char)
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    if _tmp
      while true
    
    _save3 = self.pos
    while true # sequence
    _save4 = self.pos
    _tmp = apply(:_CRLF)
    unless _tmp
      _tmp = true
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_LWSP_char)
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    set_failed_rule :_linear_white_space unless _tmp
    return _tmp
  end

  # atom = /[^\]\x00-\x20 \x7F\x80-\xFF()<>@,;:\\".\[]+/
  def _atom
    _tmp = scan(/\A(?-mix:[^\]\x00-\x20 \x7F\x80-\xFF()<>@,;:\\".\[]+)/)
    set_failed_rule :_atom unless _tmp
    return _tmp
  end

  # ctext = (/[^)\\\x0D\x80-\xFF(]+/ | linear_white_space)
  def _ctext

    _save = self.pos
    while true # choice
    _tmp = scan(/\A(?-mix:[^)\\\x0D\x80-\xFF(]+)/)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_linear_white_space)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_ctext unless _tmp
    return _tmp
  end

  # dtext = (/[^\]\\\x0D\x80-\xFF\[]+/ | linear_white_space)
  def _dtext

    _save = self.pos
    while true # choice
    _tmp = scan(/\A(?-mix:[^\]\\\x0D\x80-\xFF\[]+)/)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_linear_white_space)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_dtext unless _tmp
    return _tmp
  end

  # qtext = (/[^"\\\x0D\x80-\xFF]+/ | linear_white_space)
  def _qtext

    _save = self.pos
    while true # choice
    _tmp = scan(/\A(?-mix:[^"\\\x0D\x80-\xFF]+)/)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_linear_white_space)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_qtext unless _tmp
    return _tmp
  end

  # quoted_pair = "\\" CHAR
  def _quoted_pair

    _save = self.pos
    while true # sequence
    _tmp = match_string("\\")
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_CHAR)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_quoted_pair unless _tmp
    return _tmp
  end

  # quoted_string = "\"" (qtext | quoted_pair)* "\""
  def _quoted_string

    _save = self.pos
    while true # sequence
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save2 = self.pos
    while true # choice
    _tmp = apply(:_qtext)
    break if _tmp
    self.pos = _save2
    _tmp = apply(:_quoted_pair)
    break if _tmp
    self.pos = _save2
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_quoted_string unless _tmp
    return _tmp
  end

  # domain_literal = "[" (dtext | quoted_pair)* "]"
  def _domain_literal

    _save = self.pos
    while true # sequence
    _tmp = match_string("[")
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save2 = self.pos
    while true # choice
    _tmp = apply(:_dtext)
    break if _tmp
    self.pos = _save2
    _tmp = apply(:_quoted_pair)
    break if _tmp
    self.pos = _save2
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("]")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_domain_literal unless _tmp
    return _tmp
  end

  # comment = "(" (ctext | quoted_pair | comment)* ")"
  def _comment

    _save = self.pos
    while true # sequence
    _tmp = match_string("(")
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save2 = self.pos
    while true # choice
    _tmp = apply(:_ctext)
    break if _tmp
    self.pos = _save2
    _tmp = apply(:_quoted_pair)
    break if _tmp
    self.pos = _save2
    _tmp = apply(:_comment)
    break if _tmp
    self.pos = _save2
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(")")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_comment unless _tmp
    return _tmp
  end

  # ocms = comment*
  def _ocms
    while true
    _tmp = apply(:_comment)
    break unless _tmp
    end
    _tmp = true
    set_failed_rule :_ocms unless _tmp
    return _tmp
  end

  # word = (atom | quoted_string)
  def _word

    _save = self.pos
    while true # choice
    _tmp = apply(:_atom)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_quoted_string)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_word unless _tmp
    return _tmp
  end

  # phrase = (word -)+
  def _phrase
    _save = self.pos

    _save1 = self.pos
    while true # sequence
    _tmp = apply(:_word)
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:__hyphen_)
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    if _tmp
      while true
    
    _save2 = self.pos
    while true # sequence
    _tmp = apply(:_word)
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:__hyphen_)
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    set_failed_rule :_phrase unless _tmp
    return _tmp
  end

  # valid = ocms address ocms
  def _valid

    _save = self.pos
    while true # sequence
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_address)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_valid unless _tmp
    return _tmp
  end

  # address = (mailbox | group)
  def _address

    _save = self.pos
    while true # choice
    _tmp = apply(:_mailbox)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_group)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_address unless _tmp
    return _tmp
  end

  # group = phrase ocms ":" ocms mailbox (ocms "," ocms mailbox)* ocms ";"
  def _group

    _save = self.pos
    while true # sequence
    _tmp = apply(:_phrase)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(":")
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_mailbox)
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save2 = self.pos
    while true # sequence
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_mailbox)
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(";")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_group unless _tmp
    return _tmp
  end

  # mailbox = (addr_spec | phrase - ocms - angle_addr)
  def _mailbox

    _save = self.pos
    while true # choice
    _tmp = apply(:_addr_spec)
    break if _tmp
    self.pos = _save

    _save1 = self.pos
    while true # sequence
    _tmp = apply(:_phrase)
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:__hyphen_)
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:__hyphen_)
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:_angle_addr)
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_mailbox unless _tmp
    return _tmp
  end

  # angle_addr = "<" ocms route? ocms addr_spec ">"
  def _angle_addr

    _save = self.pos
    while true # sequence
    _tmp = match_string("<")
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _save1 = self.pos
    _tmp = apply(:_route)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_addr_spec)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(">")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_angle_addr unless _tmp
    return _tmp
  end

  # route = (AT ocms domain)+ ":"
  def _route

    _save = self.pos
    while true # sequence
    _save1 = self.pos

    _save2 = self.pos
    while true # sequence
    _tmp = apply(:_AT)
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_domain)
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

    if _tmp
      while true
    
    _save3 = self.pos
    while true # sequence
    _tmp = apply(:_AT)
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_domain)
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(":")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_route unless _tmp
    return _tmp
  end

  # addr_spec = local_part ocms "@" ocms domain
  def _addr_spec

    _save = self.pos
    while true # sequence
    _tmp = apply(:_local_part)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("@")
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_domain)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_addr_spec unless _tmp
    return _tmp
  end

  # local_part = word ocms ("." ocms word)*
  def _local_part

    _save = self.pos
    while true # sequence
    _tmp = apply(:_word)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save2 = self.pos
    while true # sequence
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_word)
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_local_part unless _tmp
    return _tmp
  end

  # domain = sub_domain ocms ("." ocms sub_domain)+
  def _domain

    _save = self.pos
    while true # sequence
    _tmp = apply(:_sub_domain)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save
      break
    end
    _save1 = self.pos

    _save2 = self.pos
    while true # sequence
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_sub_domain)
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

    if _tmp
      while true
    
    _save3 = self.pos
    while true # sequence
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_ocms)
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_sub_domain)
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_domain unless _tmp
    return _tmp
  end

  # sub_domain = (domain_ref | domain_literal)
  def _sub_domain

    _save = self.pos
    while true # choice
    _tmp = apply(:_domain_ref)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_domain_literal)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_sub_domain unless _tmp
    return _tmp
  end

  # domain_ref = atom
  def _domain_ref
    _tmp = apply(:_atom)
    set_failed_rule :_domain_ref unless _tmp
    return _tmp
  end

  # root = valid !.
  def _root

    _save = self.pos
    while true # sequence
    _tmp = apply(:_valid)
    unless _tmp
      self.pos = _save
      break
    end
    _save1 = self.pos
    _tmp = get_byte
    _tmp = _tmp ? nil : true
    self.pos = _save1
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_HTAB] = rule_info("HTAB", "/\\x09/")
  Rules[:_LF] = rule_info("LF", "/\\x0A/")
  Rules[:_CR] = rule_info("CR", "/\\x0D/")
  Rules[:_SPACE] = rule_info("SPACE", "\" \"")
  Rules[:__hyphen_] = rule_info("-", "SPACE*")
  Rules[:_AT] = rule_info("AT", "\"@\"")
  Rules[:_LWSP_char] = rule_info("LWSP_char", "(SPACE | HTAB)")
  Rules[:_CHAR] = rule_info("CHAR", "/[\\x00-\\x7f]/")
  Rules[:_CTL] = rule_info("CTL", "/[\\x00-\\x1f\\x7f]/")
  Rules[:_special] = rule_info("special", "/[\\]()<>@,;:\\\\\".\\[]/")
  Rules[:_CRLF] = rule_info("CRLF", "CR LF")
  Rules[:_linear_white_space] = rule_info("linear_white_space", "(CRLF? LWSP_char)+")
  Rules[:_atom] = rule_info("atom", "/[^\\]\\x00-\\x20 \\x7F\\x80-\\xFF()<>@,;:\\\\\".\\[]+/")
  Rules[:_ctext] = rule_info("ctext", "(/[^)\\\\\\x0D\\x80-\\xFF(]+/ | linear_white_space)")
  Rules[:_dtext] = rule_info("dtext", "(/[^\\]\\\\\\x0D\\x80-\\xFF\\[]+/ | linear_white_space)")
  Rules[:_qtext] = rule_info("qtext", "(/[^\"\\\\\\x0D\\x80-\\xFF]+/ | linear_white_space)")
  Rules[:_quoted_pair] = rule_info("quoted_pair", "\"\\\\\" CHAR")
  Rules[:_quoted_string] = rule_info("quoted_string", "\"\\\"\" (qtext | quoted_pair)* \"\\\"\"")
  Rules[:_domain_literal] = rule_info("domain_literal", "\"[\" (dtext | quoted_pair)* \"]\"")
  Rules[:_comment] = rule_info("comment", "\"(\" (ctext | quoted_pair | comment)* \")\"")
  Rules[:_ocms] = rule_info("ocms", "comment*")
  Rules[:_word] = rule_info("word", "(atom | quoted_string)")
  Rules[:_phrase] = rule_info("phrase", "(word -)+")
  Rules[:_valid] = rule_info("valid", "ocms address ocms")
  Rules[:_address] = rule_info("address", "(mailbox | group)")
  Rules[:_group] = rule_info("group", "phrase ocms \":\" ocms mailbox (ocms \",\" ocms mailbox)* ocms \";\"")
  Rules[:_mailbox] = rule_info("mailbox", "(addr_spec | phrase - ocms - angle_addr)")
  Rules[:_angle_addr] = rule_info("angle_addr", "\"<\" ocms route? ocms addr_spec \">\"")
  Rules[:_route] = rule_info("route", "(AT ocms domain)+ \":\"")
  Rules[:_addr_spec] = rule_info("addr_spec", "local_part ocms \"@\" ocms domain")
  Rules[:_local_part] = rule_info("local_part", "word ocms (\".\" ocms word)*")
  Rules[:_domain] = rule_info("domain", "sub_domain ocms (\".\" ocms sub_domain)+")
  Rules[:_sub_domain] = rule_info("sub_domain", "(domain_ref | domain_literal)")
  Rules[:_domain_ref] = rule_info("domain_ref", "atom")
  Rules[:_root] = rule_info("root", "valid !.")
end

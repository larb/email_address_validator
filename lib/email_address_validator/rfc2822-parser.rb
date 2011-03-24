class EmailAddressValidator::RFC2822Parser
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

 attr_accessor :validate_domain 

  def setup_foreign_grammar; end

  # d = < . > &{ text[0] == num }
  def _d(num)

    _save = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = get_byte
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save
      break
    end
    _save1 = self.pos
    _tmp = begin;  text[0] == num ; end
    self.pos = _save1
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_d unless _tmp
    return _tmp
  end

  # d_btw = < . > &{ t = text[0]; t >= start && t <= fin }
  def _d_btw(start,fin)

    _save = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = get_byte
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save
      break
    end
    _save1 = self.pos
    _tmp = begin;  t = text[0]; t >= start && t <= fin ; end
    self.pos = _save1
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_d_btw unless _tmp
    return _tmp
  end

  # WSP = (" " | d(9))
  def _WSP

    _save = self.pos
    while true # choice
    _tmp = match_string(" ")
    break if _tmp
    self.pos = _save
    _tmp = _d(9)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_WSP unless _tmp
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

  # ALPHA = /[A-Za-z]/
  def _ALPHA
    _tmp = scan(/\A(?-mix:[A-Za-z])/)
    set_failed_rule :_ALPHA unless _tmp
    return _tmp
  end

  # DIGIT = /[0-9]/
  def _DIGIT
    _tmp = scan(/\A(?-mix:[0-9])/)
    set_failed_rule :_DIGIT unless _tmp
    return _tmp
  end

  # NO-WS-CTL = (d_btw(1,8) | d(11) | d(12) | d_btw(14,31) | d(127))
  def _NO_hyphen_WS_hyphen_CTL

    _save = self.pos
    while true # choice
    _tmp = _d_btw(1,8)
    break if _tmp
    self.pos = _save
    _tmp = _d(11)
    break if _tmp
    self.pos = _save
    _tmp = _d(12)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(14,31)
    break if _tmp
    self.pos = _save
    _tmp = _d(127)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_NO_hyphen_WS_hyphen_CTL unless _tmp
    return _tmp
  end

  # text = (d_btw(1,9) | d(11) | d(12) | d_btw(14,127) | obs-text)
  def _text

    _save = self.pos
    while true # choice
    _tmp = _d_btw(1,9)
    break if _tmp
    self.pos = _save
    _tmp = _d(11)
    break if _tmp
    self.pos = _save
    _tmp = _d(12)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(14,127)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_text)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_text unless _tmp
    return _tmp
  end

  # quoted-pair = ("\\" text | obs-qp)
  def _quoted_hyphen_pair

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _tmp = match_string("\\")
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:_text)
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_qp)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_quoted_hyphen_pair unless _tmp
    return _tmp
  end

  # FWS = ((WSP* CRLF)? WSP+ | obs-FWS)
  def _FWS

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _save2 = self.pos

    _save3 = self.pos
    while true # sequence
    while true
    _tmp = apply(:_WSP)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_CRLF)
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    unless _tmp
      _tmp = true
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save1
      break
    end
    _save5 = self.pos
    _tmp = apply(:_WSP)
    if _tmp
      while true
        _tmp = apply(:_WSP)
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save5
    end
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_FWS)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_FWS unless _tmp
    return _tmp
  end

  # ctext = (NO-WS-CTL | d_btw(33,39) | d_btw(42,91) | d_btw(93,126))
  def _ctext

    _save = self.pos
    while true # choice
    _tmp = apply(:_NO_hyphen_WS_hyphen_CTL)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(33,39)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(42,91)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(93,126)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_ctext unless _tmp
    return _tmp
  end

  # ccontent = (ctext | quoted-pair | comment)
  def _ccontent

    _save = self.pos
    while true # choice
    _tmp = apply(:_ctext)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_quoted_hyphen_pair)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_comment)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_ccontent unless _tmp
    return _tmp
  end

  # comment = "(" (FWS? ccontent)* FWS? ")"
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
    while true # sequence
    _save3 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_ccontent)
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
    _save4 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save4
    end
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

  # CFWS = (FWS? comment)* (FWS? comment | FWS)
  def _CFWS

    _save = self.pos
    while true # sequence
    while true

    _save2 = self.pos
    while true # sequence
    _save3 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_comment)
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

    _save4 = self.pos
    while true # choice

    _save5 = self.pos
    while true # sequence
    _save6 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save6
    end
    unless _tmp
      self.pos = _save5
      break
    end
    _tmp = apply(:_comment)
    unless _tmp
      self.pos = _save5
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save4
    _tmp = apply(:_FWS)
    break if _tmp
    self.pos = _save4
    break
    end # end choice

    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_CFWS unless _tmp
    return _tmp
  end

  # atext = (ALPHA | DIGIT | "!" | "#" | "$" | "%" | "&" | "'" | "*" | "+" | "-" | "/" | "=" | "?" | "^" | "_" | "`" | "{" | "|" | "}" | "~")
  def _atext

    _save = self.pos
    while true # choice
    _tmp = apply(:_ALPHA)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_DIGIT)
    break if _tmp
    self.pos = _save
    _tmp = match_string("!")
    break if _tmp
    self.pos = _save
    _tmp = match_string("#")
    break if _tmp
    self.pos = _save
    _tmp = match_string("$")
    break if _tmp
    self.pos = _save
    _tmp = match_string("%")
    break if _tmp
    self.pos = _save
    _tmp = match_string("&")
    break if _tmp
    self.pos = _save
    _tmp = match_string("'")
    break if _tmp
    self.pos = _save
    _tmp = match_string("*")
    break if _tmp
    self.pos = _save
    _tmp = match_string("+")
    break if _tmp
    self.pos = _save
    _tmp = match_string("-")
    break if _tmp
    self.pos = _save
    _tmp = match_string("/")
    break if _tmp
    self.pos = _save
    _tmp = match_string("=")
    break if _tmp
    self.pos = _save
    _tmp = match_string("?")
    break if _tmp
    self.pos = _save
    _tmp = match_string("^")
    break if _tmp
    self.pos = _save
    _tmp = match_string("_")
    break if _tmp
    self.pos = _save
    _tmp = match_string("`")
    break if _tmp
    self.pos = _save
    _tmp = match_string("{")
    break if _tmp
    self.pos = _save
    _tmp = match_string("|")
    break if _tmp
    self.pos = _save
    _tmp = match_string("}")
    break if _tmp
    self.pos = _save
    _tmp = match_string("~")
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_atext unless _tmp
    return _tmp
  end

  # atom = CFWS? atext+ CFWS?
  def _atom

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _save2 = self.pos
    _tmp = apply(:_atext)
    if _tmp
      while true
        _tmp = apply(:_atext)
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save
      break
    end
    _save3 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_atom unless _tmp
    return _tmp
  end

  # dot-atom = CFWS? dot-atom-text CFWS?
  def _dot_hyphen_atom

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_dot_hyphen_atom_hyphen_text)
    unless _tmp
      self.pos = _save
      break
    end
    _save2 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_dot_hyphen_atom unless _tmp
    return _tmp
  end

  # dot-atom-text = atext+ ("." atext+)*
  def _dot_hyphen_atom_hyphen_text

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_atext)
    if _tmp
      while true
        _tmp = apply(:_atext)
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
    while true

    _save3 = self.pos
    while true # sequence
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save3
      break
    end
    _save4 = self.pos
    _tmp = apply(:_atext)
    if _tmp
      while true
        _tmp = apply(:_atext)
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save3
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

    set_failed_rule :_dot_hyphen_atom_hyphen_text unless _tmp
    return _tmp
  end

  # qtext = (NO-WS-CTL | d(33) | d_btw(35,91) | d_btw(93,126))
  def _qtext

    _save = self.pos
    while true # choice
    _tmp = apply(:_NO_hyphen_WS_hyphen_CTL)
    break if _tmp
    self.pos = _save
    _tmp = _d(33)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(35,91)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(93,126)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_qtext unless _tmp
    return _tmp
  end

  # qcontent = (qtext | quoted-pair)
  def _qcontent

    _save = self.pos
    while true # choice
    _tmp = apply(:_qtext)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_quoted_hyphen_pair)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_qcontent unless _tmp
    return _tmp
  end

  # quoted-string = CFWS? "\"" (FWS? qcontent)* FWS? "\"" CFWS?
  def _quoted_hyphen_string

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save3 = self.pos
    while true # sequence
    _save4 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_qcontent)
    unless _tmp
      self.pos = _save3
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
    _save5 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save5
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save
      break
    end
    _save6 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save6
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_quoted_hyphen_string unless _tmp
    return _tmp
  end

  # word = (atom | quoted-string)
  def _word

    _save = self.pos
    while true # choice
    _tmp = apply(:_atom)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_quoted_hyphen_string)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_word unless _tmp
    return _tmp
  end

  # phrase = (word+ | obs-phrase)
  def _phrase

    _save = self.pos
    while true # choice
    _save1 = self.pos
    _tmp = apply(:_word)
    if _tmp
      while true
        _tmp = apply(:_word)
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save1
    end
    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_phrase)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_phrase unless _tmp
    return _tmp
  end

  # utext = (NO-WS-CTL | d_btw(33,126) | obs-utext)
  def _utext

    _save = self.pos
    while true # choice
    _tmp = apply(:_NO_hyphen_WS_hyphen_CTL)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(33,126)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_utext)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_utext unless _tmp
    return _tmp
  end

  # unstructured = (FWS? utext)* FWS?
  def _unstructured

    _save = self.pos
    while true # sequence
    while true

    _save2 = self.pos
    while true # sequence
    _save3 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_utext)
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
    _save4 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_unstructured unless _tmp
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

  # mailbox = (name-addr | addr-spec)
  def _mailbox

    _save = self.pos
    while true # choice
    _tmp = apply(:_name_hyphen_addr)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_addr_hyphen_spec)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_mailbox unless _tmp
    return _tmp
  end

  # name-addr = display-name? angle-addr
  def _name_hyphen_addr

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_display_hyphen_name)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_angle_hyphen_addr)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_name_hyphen_addr unless _tmp
    return _tmp
  end

  # angle-addr = (CFWS? "<" addr-spec ">" CFWS? | obs-angle-addr)
  def _angle_hyphen_addr

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _save2 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = match_string("<")
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = apply(:_addr_hyphen_spec)
    unless _tmp
      self.pos = _save1
      break
    end
    _tmp = match_string(">")
    unless _tmp
      self.pos = _save1
      break
    end
    _save3 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_angle_hyphen_addr)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_angle_hyphen_addr unless _tmp
    return _tmp
  end

  # group = display-name ":" (mailbox-list | CFWS)? ";" CFWS?
  def _group

    _save = self.pos
    while true # sequence
    _tmp = apply(:_display_hyphen_name)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(":")
    unless _tmp
      self.pos = _save
      break
    end
    _save1 = self.pos

    _save2 = self.pos
    while true # choice
    _tmp = apply(:_mailbox_hyphen_list)
    break if _tmp
    self.pos = _save2
    _tmp = apply(:_CFWS)
    break if _tmp
    self.pos = _save2
    break
    end # end choice

    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(";")
    unless _tmp
      self.pos = _save
      break
    end
    _save3 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_group unless _tmp
    return _tmp
  end

  # display-name = phrase
  def _display_hyphen_name
    _tmp = apply(:_phrase)
    set_failed_rule :_display_hyphen_name unless _tmp
    return _tmp
  end

  # mailbox-list = (mailbox ("," mailbox)* | obs-mbox-list)
  def _mailbox_hyphen_list

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _tmp = apply(:_mailbox)
    unless _tmp
      self.pos = _save1
      break
    end
    while true

    _save3 = self.pos
    while true # sequence
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_mailbox)
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_mbox_hyphen_list)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_mailbox_hyphen_list unless _tmp
    return _tmp
  end

  # address-list = (address ("," address)* | obs-addr-list)
  def _address_hyphen_list

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _tmp = apply(:_address)
    unless _tmp
      self.pos = _save1
      break
    end
    while true

    _save3 = self.pos
    while true # sequence
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_address)
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_addr_hyphen_list)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_address_hyphen_list unless _tmp
    return _tmp
  end

  # addr-spec = local-part "@" domain
  def _addr_hyphen_spec

    _save = self.pos
    while true # sequence
    _tmp = apply(:_local_hyphen_part)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("@")
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

    set_failed_rule :_addr_hyphen_spec unless _tmp
    return _tmp
  end

  # local-part = (dot-atom | quoted-string | obs-local-part)
  def _local_hyphen_part

    _save = self.pos
    while true # choice
    _tmp = apply(:_dot_hyphen_atom)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_quoted_hyphen_string)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_obs_hyphen_local_hyphen_part)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_local_hyphen_part unless _tmp
    return _tmp
  end

  # domain = (< dot-atom > &{ @validate_domain ? RFC822::DomainParser.new(text).parse : true } | domain-literal | < obs-domain > &{ @validate_domain ? RFC822::DomainParser.new(text).parse : true })
  def _domain

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = apply(:_dot_hyphen_atom)
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save1
      break
    end
    _save2 = self.pos
    _tmp = begin;  @validate_domain ? RFC822::DomainParser.new(text).parse : true ; end
    self.pos = _save2
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    _tmp = apply(:_domain_hyphen_literal)
    break if _tmp
    self.pos = _save

    _save3 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = apply(:_obs_hyphen_domain)
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save3
      break
    end
    _save4 = self.pos
    _tmp = begin;  @validate_domain ? RFC822::DomainParser.new(text).parse : true ; end
    self.pos = _save4
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_domain unless _tmp
    return _tmp
  end

  # domain-literal = CFWS? "[" (FWS? dcontent)* FWS? "]" CFWS?
  def _domain_hyphen_literal

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("[")
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save3 = self.pos
    while true # sequence
    _save4 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = apply(:_dcontent)
    unless _tmp
      self.pos = _save3
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
    _save5 = self.pos
    _tmp = apply(:_FWS)
    unless _tmp
      _tmp = true
      self.pos = _save5
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("]")
    unless _tmp
      self.pos = _save
      break
    end
    _save6 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save6
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_domain_hyphen_literal unless _tmp
    return _tmp
  end

  # dcontent = (dtext | quoted-pair)
  def _dcontent

    _save = self.pos
    while true # choice
    _tmp = apply(:_dtext)
    break if _tmp
    self.pos = _save
    _tmp = apply(:_quoted_hyphen_pair)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_dcontent unless _tmp
    return _tmp
  end

  # dtext = (NO-WS-CTL | d_btw(33,90) | d_btw(94,126))
  def _dtext

    _save = self.pos
    while true # choice
    _tmp = apply(:_NO_hyphen_WS_hyphen_CTL)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(33,90)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(94,126)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_dtext unless _tmp
    return _tmp
  end

  # obs-qp = "\\" d_btw(0,127)
  def _obs_hyphen_qp

    _save = self.pos
    while true # sequence
    _tmp = match_string("\\")
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = _d_btw(0,127)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_obs_hyphen_qp unless _tmp
    return _tmp
  end

  # obs-text = LF* CR* (obs-char LF* CR*)*
  def _obs_hyphen_text

    _save = self.pos
    while true # sequence
    while true
    _tmp = apply(:_LF)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
      break
    end
    while true
    _tmp = apply(:_CR)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save4 = self.pos
    while true # sequence
    _tmp = apply(:_obs_hyphen_char)
    unless _tmp
      self.pos = _save4
      break
    end
    while true
    _tmp = apply(:_LF)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save4
      break
    end
    while true
    _tmp = apply(:_CR)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save4
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

    set_failed_rule :_obs_hyphen_text unless _tmp
    return _tmp
  end

  # obs-char = (d_btw(0,9) | d(11) | d(12) | d_btw(14,127))
  def _obs_hyphen_char

    _save = self.pos
    while true # choice
    _tmp = _d_btw(0,9)
    break if _tmp
    self.pos = _save
    _tmp = _d(11)
    break if _tmp
    self.pos = _save
    _tmp = _d(12)
    break if _tmp
    self.pos = _save
    _tmp = _d_btw(14,127)
    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_obs_hyphen_char unless _tmp
    return _tmp
  end

  # obs-utext = obs-text
  def _obs_hyphen_utext
    _tmp = apply(:_obs_hyphen_text)
    set_failed_rule :_obs_hyphen_utext unless _tmp
    return _tmp
  end

  # obs-phrase = word (word | "." | CFWS)*
  def _obs_hyphen_phrase

    _save = self.pos
    while true # sequence
    _tmp = apply(:_word)
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save2 = self.pos
    while true # choice
    _tmp = apply(:_word)
    break if _tmp
    self.pos = _save2
    _tmp = match_string(".")
    break if _tmp
    self.pos = _save2
    _tmp = apply(:_CFWS)
    break if _tmp
    self.pos = _save2
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_obs_hyphen_phrase unless _tmp
    return _tmp
  end

  # obs-phrase-list = (phrase | (phrase? CFWS? "," CFWS?)+ phrase?)
  def _obs_hyphen_phrase_hyphen_list

    _save = self.pos
    while true # choice
    _tmp = apply(:_phrase)
    break if _tmp
    self.pos = _save

    _save1 = self.pos
    while true # sequence
    _save2 = self.pos

    _save3 = self.pos
    while true # sequence
    _save4 = self.pos
    _tmp = apply(:_phrase)
    unless _tmp
      _tmp = true
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save3
      break
    end
    _save5 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save5
    end
    unless _tmp
      self.pos = _save3
      break
    end
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save3
      break
    end
    _save6 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save6
    end
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    if _tmp
      while true
    
    _save7 = self.pos
    while true # sequence
    _save8 = self.pos
    _tmp = apply(:_phrase)
    unless _tmp
      _tmp = true
      self.pos = _save8
    end
    unless _tmp
      self.pos = _save7
      break
    end
    _save9 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save9
    end
    unless _tmp
      self.pos = _save7
      break
    end
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save7
      break
    end
    _save10 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save10
    end
    unless _tmp
      self.pos = _save7
    end
    break
    end # end sequence

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save1
      break
    end
    _save11 = self.pos
    _tmp = apply(:_phrase)
    unless _tmp
      _tmp = true
      self.pos = _save11
    end
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_obs_hyphen_phrase_hyphen_list unless _tmp
    return _tmp
  end

  # obs-FWS = WSP+ (CRLF WSP+)*
  def _obs_hyphen_FWS

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_WSP)
    if _tmp
      while true
        _tmp = apply(:_WSP)
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
    while true

    _save3 = self.pos
    while true # sequence
    _tmp = apply(:_CRLF)
    unless _tmp
      self.pos = _save3
      break
    end
    _save4 = self.pos
    _tmp = apply(:_WSP)
    if _tmp
      while true
        _tmp = apply(:_WSP)
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save3
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

    set_failed_rule :_obs_hyphen_FWS unless _tmp
    return _tmp
  end

  # obs-angle-addr = CFWS? "<" obs-route? addr-spec ">" CFWS?
  def _obs_hyphen_angle_hyphen_addr

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("<")
    unless _tmp
      self.pos = _save
      break
    end
    _save2 = self.pos
    _tmp = apply(:_obs_hyphen_route)
    unless _tmp
      _tmp = true
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_addr_hyphen_spec)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(">")
    unless _tmp
      self.pos = _save
      break
    end
    _save3 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_obs_hyphen_angle_hyphen_addr unless _tmp
    return _tmp
  end

  # obs-route = CFWS? obs-domain-list ":" CFWS?
  def _obs_hyphen_route

    _save = self.pos
    while true # sequence
    _save1 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save1
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_obs_hyphen_domain_hyphen_list)
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string(":")
    unless _tmp
      self.pos = _save
      break
    end
    _save2 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save2
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_obs_hyphen_route unless _tmp
    return _tmp
  end

  # obs-domain-list = "@" domain ((CFWS | ",")* CFWS? "@" domain)*
  def _obs_hyphen_domain_hyphen_list

    _save = self.pos
    while true # sequence
    _tmp = match_string("@")
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = apply(:_domain)
    unless _tmp
      self.pos = _save
      break
    end
    while true

    _save2 = self.pos
    while true # sequence
    while true

    _save4 = self.pos
    while true # choice
    _tmp = apply(:_CFWS)
    break if _tmp
    self.pos = _save4
    _tmp = match_string(",")
    break if _tmp
    self.pos = _save4
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save2
      break
    end
    _save5 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save5
    end
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = match_string("@")
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

    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_obs_hyphen_domain_hyphen_list unless _tmp
    return _tmp
  end

  # obs-local-part = word ("." word)*
  def _obs_hyphen_local_hyphen_part

    _save = self.pos
    while true # sequence
    _tmp = apply(:_word)
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

    set_failed_rule :_obs_hyphen_local_hyphen_part unless _tmp
    return _tmp
  end

  # obs-domain = atom ("." atom)*
  def _obs_hyphen_domain

    _save = self.pos
    while true # sequence
    _tmp = apply(:_atom)
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
    _tmp = apply(:_atom)
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

    set_failed_rule :_obs_hyphen_domain unless _tmp
    return _tmp
  end

  # obs-mbox-list = (address? CFWS? "," CFWS?)+ address?
  def _obs_hyphen_mbox_hyphen_list

    _save = self.pos
    while true # sequence
    _save1 = self.pos

    _save2 = self.pos
    while true # sequence
    _save3 = self.pos
    _tmp = apply(:_address)
    unless _tmp
      _tmp = true
      self.pos = _save3
    end
    unless _tmp
      self.pos = _save2
      break
    end
    _save4 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save4
    end
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save2
      break
    end
    _save5 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save5
    end
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

    if _tmp
      while true
    
    _save6 = self.pos
    while true # sequence
    _save7 = self.pos
    _tmp = apply(:_address)
    unless _tmp
      _tmp = true
      self.pos = _save7
    end
    unless _tmp
      self.pos = _save6
      break
    end
    _save8 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save8
    end
    unless _tmp
      self.pos = _save6
      break
    end
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save6
      break
    end
    _save9 = self.pos
    _tmp = apply(:_CFWS)
    unless _tmp
      _tmp = true
      self.pos = _save9
    end
    unless _tmp
      self.pos = _save6
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
    _save10 = self.pos
    _tmp = apply(:_address)
    unless _tmp
      _tmp = true
      self.pos = _save10
    end
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_obs_hyphen_mbox_hyphen_list unless _tmp
    return _tmp
  end

  # root = address !.
  def _root

    _save = self.pos
    while true # sequence
    _tmp = apply(:_address)
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

  # only_addr_spec = addr-spec !.
  def _only_addr_spec

    _save = self.pos
    while true # sequence
    _tmp = apply(:_addr_hyphen_spec)
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

    set_failed_rule :_only_addr_spec unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_d] = rule_info("d", "< . > &{ text[0] == num }")
  Rules[:_d_btw] = rule_info("d_btw", "< . > &{ t = text[0]; t >= start && t <= fin }")
  Rules[:_WSP] = rule_info("WSP", "(\" \" | d(9))")
  Rules[:_LF] = rule_info("LF", "/\\x0A/")
  Rules[:_CR] = rule_info("CR", "/\\x0D/")
  Rules[:_CRLF] = rule_info("CRLF", "CR LF")
  Rules[:_ALPHA] = rule_info("ALPHA", "/[A-Za-z]/")
  Rules[:_DIGIT] = rule_info("DIGIT", "/[0-9]/")
  Rules[:_NO_hyphen_WS_hyphen_CTL] = rule_info("NO-WS-CTL", "(d_btw(1,8) | d(11) | d(12) | d_btw(14,31) | d(127))")
  Rules[:_text] = rule_info("text", "(d_btw(1,9) | d(11) | d(12) | d_btw(14,127) | obs-text)")
  Rules[:_quoted_hyphen_pair] = rule_info("quoted-pair", "(\"\\\\\" text | obs-qp)")
  Rules[:_FWS] = rule_info("FWS", "((WSP* CRLF)? WSP+ | obs-FWS)")
  Rules[:_ctext] = rule_info("ctext", "(NO-WS-CTL | d_btw(33,39) | d_btw(42,91) | d_btw(93,126))")
  Rules[:_ccontent] = rule_info("ccontent", "(ctext | quoted-pair | comment)")
  Rules[:_comment] = rule_info("comment", "\"(\" (FWS? ccontent)* FWS? \")\"")
  Rules[:_CFWS] = rule_info("CFWS", "(FWS? comment)* (FWS? comment | FWS)")
  Rules[:_atext] = rule_info("atext", "(ALPHA | DIGIT | \"!\" | \"\#\" | \"$\" | \"%\" | \"&\" | \"'\" | \"*\" | \"+\" | \"-\" | \"/\" | \"=\" | \"?\" | \"^\" | \"_\" | \"`\" | \"{\" | \"|\" | \"}\" | \"~\")")
  Rules[:_atom] = rule_info("atom", "CFWS? atext+ CFWS?")
  Rules[:_dot_hyphen_atom] = rule_info("dot-atom", "CFWS? dot-atom-text CFWS?")
  Rules[:_dot_hyphen_atom_hyphen_text] = rule_info("dot-atom-text", "atext+ (\".\" atext+)*")
  Rules[:_qtext] = rule_info("qtext", "(NO-WS-CTL | d(33) | d_btw(35,91) | d_btw(93,126))")
  Rules[:_qcontent] = rule_info("qcontent", "(qtext | quoted-pair)")
  Rules[:_quoted_hyphen_string] = rule_info("quoted-string", "CFWS? \"\\\"\" (FWS? qcontent)* FWS? \"\\\"\" CFWS?")
  Rules[:_word] = rule_info("word", "(atom | quoted-string)")
  Rules[:_phrase] = rule_info("phrase", "(word+ | obs-phrase)")
  Rules[:_utext] = rule_info("utext", "(NO-WS-CTL | d_btw(33,126) | obs-utext)")
  Rules[:_unstructured] = rule_info("unstructured", "(FWS? utext)* FWS?")
  Rules[:_address] = rule_info("address", "(mailbox | group)")
  Rules[:_mailbox] = rule_info("mailbox", "(name-addr | addr-spec)")
  Rules[:_name_hyphen_addr] = rule_info("name-addr", "display-name? angle-addr")
  Rules[:_angle_hyphen_addr] = rule_info("angle-addr", "(CFWS? \"<\" addr-spec \">\" CFWS? | obs-angle-addr)")
  Rules[:_group] = rule_info("group", "display-name \":\" (mailbox-list | CFWS)? \";\" CFWS?")
  Rules[:_display_hyphen_name] = rule_info("display-name", "phrase")
  Rules[:_mailbox_hyphen_list] = rule_info("mailbox-list", "(mailbox (\",\" mailbox)* | obs-mbox-list)")
  Rules[:_address_hyphen_list] = rule_info("address-list", "(address (\",\" address)* | obs-addr-list)")
  Rules[:_addr_hyphen_spec] = rule_info("addr-spec", "local-part \"@\" domain")
  Rules[:_local_hyphen_part] = rule_info("local-part", "(dot-atom | quoted-string | obs-local-part)")
  Rules[:_domain] = rule_info("domain", "(< dot-atom > &{ @validate_domain ? RFC822::DomainParser.new(text).parse : true } | domain-literal | < obs-domain > &{ @validate_domain ? RFC822::DomainParser.new(text).parse : true })")
  Rules[:_domain_hyphen_literal] = rule_info("domain-literal", "CFWS? \"[\" (FWS? dcontent)* FWS? \"]\" CFWS?")
  Rules[:_dcontent] = rule_info("dcontent", "(dtext | quoted-pair)")
  Rules[:_dtext] = rule_info("dtext", "(NO-WS-CTL | d_btw(33,90) | d_btw(94,126))")
  Rules[:_obs_hyphen_qp] = rule_info("obs-qp", "\"\\\\\" d_btw(0,127)")
  Rules[:_obs_hyphen_text] = rule_info("obs-text", "LF* CR* (obs-char LF* CR*)*")
  Rules[:_obs_hyphen_char] = rule_info("obs-char", "(d_btw(0,9) | d(11) | d(12) | d_btw(14,127))")
  Rules[:_obs_hyphen_utext] = rule_info("obs-utext", "obs-text")
  Rules[:_obs_hyphen_phrase] = rule_info("obs-phrase", "word (word | \".\" | CFWS)*")
  Rules[:_obs_hyphen_phrase_hyphen_list] = rule_info("obs-phrase-list", "(phrase | (phrase? CFWS? \",\" CFWS?)+ phrase?)")
  Rules[:_obs_hyphen_FWS] = rule_info("obs-FWS", "WSP+ (CRLF WSP+)*")
  Rules[:_obs_hyphen_angle_hyphen_addr] = rule_info("obs-angle-addr", "CFWS? \"<\" obs-route? addr-spec \">\" CFWS?")
  Rules[:_obs_hyphen_route] = rule_info("obs-route", "CFWS? obs-domain-list \":\" CFWS?")
  Rules[:_obs_hyphen_domain_hyphen_list] = rule_info("obs-domain-list", "\"@\" domain ((CFWS | \",\")* CFWS? \"@\" domain)*")
  Rules[:_obs_hyphen_local_hyphen_part] = rule_info("obs-local-part", "word (\".\" word)*")
  Rules[:_obs_hyphen_domain] = rule_info("obs-domain", "atom (\".\" atom)*")
  Rules[:_obs_hyphen_mbox_hyphen_list] = rule_info("obs-mbox-list", "(address? CFWS? \",\" CFWS?)+ address?")
  Rules[:_root] = rule_info("root", "address !.")
  Rules[:_only_addr_spec] = rule_info("only_addr_spec", "addr-spec !.")
end

require 'get_pomo/translation'

module GetPomo
  class PoFile
    def self.parse(text)
      PoFile.new.add_translations_from_text(text)
    end

    def self.to_text(translations)
      p = PoFile.new(:translations=>translations)
      p.to_text
    end

    attr_reader :translations

    def initialize(options = {})
      @translations = options[:translations] || []
    end

    #the text is split into lines and then converted into logical translations
    #each translation consists of comments(that come before a translation)
    #and a msgid / msgstr
    def add_translations_from_text(text)
      start_new_translation
      text.split(/$/).each_with_index do |line,index|
        @line_number = index + 1
        next if line.empty?
        if method_call? line
          parse_method_call line
        elsif comment? line
          add_comment line
        else
          add_string line
        end
      end
      start_new_translation #instance_variable has to be overwritten or errors can occur on next add
      translations
    end

    def to_text
      GetPomo.unique_translations(translations).map {|translation|
        comment = translation.comment.to_s.split(/\n|\r\n/).map{|line|"#{line}\n"}*''
        msgid_and_msgstr = if translation.plural?
          msgids =
          %Q(msgid "#{escape_quotes(translation.msgid[0])}"\n)+
          %Q(msgid_plural "#{escape_quotes(translation.msgid[1])}"\n)

          msgstrs = []
          translation.msgstr.each_with_index do |msgstr,index|
            msgstrs << %Q(msgstr[#{index}] "#{escape_quotes(msgstr)}")
          end

          msgids + (msgstrs*"\n")
        else
          %Q(msgid "#{escape_quotes(translation.msgid)}"\n)+
          %Q(msgstr "#{escape_quotes(translation.msgstr)}")
        end

        comment + msgid_and_msgstr
      } * "\n\n"
    end

    private

    def escape_quotes(txt)
      txt.gsub /"/, '\"'
    end


    #e.g. # fuzzy
    def comment?(line)
      line =~ /^\s*#/
    end

    def add_comment(line)
      start_new_translation if translation_complete?
      @current_translation.add_text(line.strip+"\n",:to=>:comment)
    end

    #msgid "hello"
    def method_call?(line)
      line =~ /^\s*[a-z]/
    end

    #msgid "hello" -> method call msgid + add string "hello"
    def parse_method_call(line)
      method, string = line.match(/^\s*([a-z0-9_\[\]]+)(.*)/)[1..2]
      raise "no method found" unless method

      start_new_translation if %W(msgid msgctxt).include? method and translation_complete?
      @last_method = method.to_sym
      add_string(string)
    end

    #"hello" -> hello
    def add_string(string)
      string = string.strip
      return if string.empty?
      raise "not string format: #{string.inspect} on line #{@line_number}" unless string =~ /^['"](.*)['"]$/
      string_content = $1.gsub(/\\"/, '"')
      @current_translation.add_text(string_content, :to=>@last_method)
    end

    def translation_complete?
      return false unless @current_translation
      @current_translation.complete?
    end
  
    def store_translation
      @translations += [@current_translation] if @current_translation.complete?
    end

    def start_new_translation
      store_translation if translation_complete?
      @current_translation = Translation.new
    end
  end
end

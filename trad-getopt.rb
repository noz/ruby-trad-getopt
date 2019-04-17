module Getopt

  VERSION = "2.0.0"

  class GetoptError < StandardError
    def initialize option, message
      super message
      @option = option
    end
    attr_reader :option
  end

  class UnknownOptionError < GetoptError
    def initialize option, message = "Unknown option"
      super option, message
    end
  end

  class ArgumentRequiredError < GetoptError
    def initialize option, message = "Option requires an argument"
      super option, message
    end
  end

  class ArgumentGivenError < GetoptError
    def initialize option, message = "Option doesn't take an argument"
      super option, message
    end
  end

  class AmbiguousOptionError < GetoptError
    def initialize option, message, candidates
      message ||= "Ambiguos option"
      @candidates = candidates
      super option, %|#{message} (#{candidates.join ","})|
    end
    attr_reader :candidates
  end

  def self.parse argv, opts, longopts,
                 abbreviation: true,
                 allow_empty_optarg: true,
                 optional_short: true,
                 permute: false,
                 program_name: nil,
                 stop_by_double_hyphen: true,
                 use_exception: false
                 # error_message:
                 # parse:

    xargv = []
    loop {
      ret = getopt argv, opts, longopts,
                   error_message: false,
                   parse: true,
                   #
                   abbreviation: abbreviation,
                   allow_empty_optarg: allow_empty_optarg,
                   optional_short: optional_short,
                   permute: permute,
                   program_name: program_name,
                   stop_by_double_hyphen: stop_by_double_hyphen,
                   use_exception: use_exception

      if ret == :stop
        xargv.push :stop
        xargv.concat argv
        break
      elsif ret.nil?
        xargv.push argv.shift
      else
        xargv.push ret
      end

      break if argv.empty?
    }
    xargv
  end

  def self.list argv, opts, longopts,
                abbreviation: true,
                allow_empty_optarg: true,
                optional_short: true,
                permute: false,
                program_name: nil,
                stop_by_double_hyphen: true,
                use_exception: false
                # error_message:
                # parse:

    xargv = []
    loop {
      ret = getopt argv, opts, longopts,
                   error_message: false,
                   parse: true,
                   #
                   abbreviation: abbreviation,
                   allow_empty_optarg: allow_empty_optarg,
                   optional_short: optional_short,
                   permute: permute,
                   program_name: program_name,
                   stop_by_double_hyphen: stop_by_double_hyphen,
                   use_exception: use_exception

      if ret == :stop
        xargv.push "--"
        xargv.concat argv
        break
      end

      if ret.nil?
        xargv.push argv.shift
      else
        case ret.first
        when :error
          xargv.push ret
        when :short
          case ret[1]
          when :no_argument
            xargv.push ret[2]
          when :required_argument
	    xargv.push %|#{ret[2]} "#{ret[3]}"|
          when :optional_argument
            if ret[3]
              xargv.push %|#{ret[2]}"#{ret[3]}"|
            else
              xargv.push ret[2]
            end
          end
        when :long
          case ret[1]
          when :no_argument
            xargv.push ret[2]
          when :required_argument
            xargv.push %|#{ret[2]}="#{ret[3]}"|
          when :optional_argument
            if ret[3]
              xargv.push %|#{ret[2]}="#{ret[3]}"|
            else
              xargv.push ret[2]
            end
          end
        end
      end

      break if argv.empty?
    }
    xargv
  end

end

def getopt argv, opts, longopts = nil,
           abbreviation: true,
           allow_empty_optarg: true,
           error_message: true,
           optional_short: true,
           parse: false,
           permute: false,
           program_name: nil,
           stop_by_double_hyphen: true,
           use_exception: false

  if permute
    args = []
    until op = getopt(argv, opts, longopts,
                      abbreviation: abbreviation,
                      allow_empty_optarg: allow_empty_optarg,
                      error_message: error_message,
                      optional_short: optional_short,
                      parse: parse,
                      permute: false,
                      program_name: program_name,
                      stop_by_double_hyphen: stop_by_double_hyphen,
                      use_exception: use_exception)

      if argv.empty?
        argv.unshift(*args)
        return nil
      end
      args.push argv.shift
    end
    argv.unshift(*args)
    return op
  end

  opts ||= ""
  program_name ||= File.basename $0

  arg = argv.shift
  return nil unless arg

  if arg == :getopt_short
    arg = argv.shift
    return nil unless arg
  else
    if arg == "-"
      argv.unshift "-"
      return nil
    end
    if stop_by_double_hyphen && arg == "--"
      return parse ? :stop : nil
    end

    # long option
    if longopts && arg.index("--") == 0

      optopt, optarg = arg[2..-1].split "=", 2

      if abbreviation
        abbr = longopts.collect {|o| o if o[0] =~ /^#{optopt}/ }.compact
        if abbr.empty?
          raise Getopt::UnknownOptionError.new "--#{optopt}"
        end
        if abbr.size == 1
          optopt = abbr.first.first
        elsif exact = abbr.find {|a| a[0] == optopt }
          optopt = exact.first
        else
          cands = abbr.collect {|o| "--#{o.first}" }
          raise Getopt::AmbiguousOptionError.new "--#{optopt}", nil, cands
        end
      else
        unless longopts[optopt]
          raise Getopt::UnknownOptionError.new "--#{optopt}"
        end
      end

      case longopts[optopt]
      when :no_argument
        if optarg
          raise Getopt::ArgumentGivenError.new "--#{optopt}"
        end
        ret = [ optopt ]
        info = [ :long, :no_argument ]
      when :required_argument
        unless optarg
          optarg = argv.shift
          unless optarg
            raise Getopt::ArgumentRequiredError.new "--#{optopt}"
          end
        end
        if ! allow_empty_optarg && optarg.empty?
          raise Getopt::ArgumentRequiredError.new "--#{optopt}"
        end
        ret = [ optopt, optarg ]
        info = [ :long, :required_argument ]
      when :optional_argument
        if ! allow_empty_optarg && optarg && optarg.empty?
          raise Getopt::ArgumentRequiredError.new "--#{optopt}"
        end
        ret = [ optopt, optarg ]
        info = [ :long, :optional_argument ]
      else
        raise ArgumentError,
              "Wrong long option type - #{longopts[optopt].inspect}"
      end

      if parse
        ret[0] = "--#{ret[0]}"
        ret = info + ret
      end
      return ret
    end
  end

  # non option argument
  unless arg[0] == "-"
    argv.unshift arg
    return nil
  end

  # short option. here arg[0] == "-"

  optopt = arg[1]
  arg = arg[2 .. -1]
  pos = opts.index optopt
  if pos.nil? || (optopt == ":" && pos != 0)
    argv.unshift "-#{arg}" unless arg.empty?
    # keep short option context on error
    argv.unshift :getopt_short if arg[0] == "-"
    raise Getopt::UnknownOptionError.new "-#{optopt}"
  end

  if opts[pos.succ] == ":"
    if optional_short && opts[pos.succ.succ] == ":"
      # short option with optional argument
      optarg = arg.empty? ? nil : arg
      ret = [ optopt, optarg ]
      info = [ :short, :optional_argument ]
    else
      # short option with required argument
      optarg = arg.empty? ? argv.shift : arg
      if optarg.nil? || (optarg.empty? && ! allow_empty_optarg)
        raise Getopt::ArgumentRequiredError.new "-#{optopt}"
      end
      ret = [ optopt, optarg ]
      info = [ :short, :required_argument ]
    end
  else
    # short option without argument
    unless arg.empty?
      argv.unshift "-#{arg}"
      argv.unshift :getopt_short if arg[0] == "-"
    end
    ret = [ optopt ]
    info = [ :short, :no_argument ]
  end

  if parse
    ret[0] = "-#{ret[0]}"
    ret = info + ret
  end
  ret

rescue Getopt::GetoptError => ex
  raise if use_exception

  warn "#{program_name}: #{ex.message}: #{ex.option}" if error_message

  case ex
  when Getopt::UnknownOptionError
    ret = [ :unknown_option, ex.option ]
  when Getopt::ArgumentRequiredError
    ret = [ :argument_required, ex.option ]
  when Getopt::ArgumentGivenError
    ret = [ :argument_given, ex.option ]
  when Getopt::AmbiguousOptionError
    ret = [ :ambiguous_option, [ ex.option, ex.candidates ]]
  end

  ret.unshift :error if parse
  return ret
end

Kernel.define_singleton_method "getopt", method(:getopt)

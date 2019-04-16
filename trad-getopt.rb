# rather traditional getopt for Ruby

module Getopt

  VERSION = "1.2.1"

  class GetoptError < StandardError
    def initialize option, message
      super message
      @option = option
    end
    attr_reader :option
  end
  class UnknownOptionError < GetoptError
    def initialize option, message = "unknown option"
      super option, message
    end
  end
  class ArgumentRequiredError < GetoptError
    def initialize option, message = "option requires an argument"
      super option, message
    end
  end
  class ArgumentGivenError < GetoptError
    def initialize option, message = "option doesn't take an argument"
      super option, message
    end
  end
  class AmbiguousOptionError < GetoptError
    def initialize option, message, candidates
      message ||= "ambiguos option"
      @candidates = candidates
      cands = candidates.collect { |c| "--#{c}" }.join " "
      super option, "#{message} (#{cands})"
    end
    attr_reader :candidates
  end
end

def getopt(argv, opts, longopts = nil,
           abbreviation: true, allow_empty_optarg: true,
           error_message: true, optional_short: true, permute: false,
           program_name: nil, stop_by_double_hyphen: true,
           use_exception: false)
  if permute
    args = []
    until op = getopt(argv, opts, longopts,
                      permute: false,
                      abbreviation: abbreviation,
                      allow_empty_optarg: allow_empty_optarg,
                      error_message: error_message,
                      optional_short: optional_short,
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
  return nil if arg.nil?
  if arg == :getopt_short
    arg = argv.shift
    return nil if arg.nil?
  else
    if arg == "-"
      argv.unshift "-"
      return nil
    end
    if stop_by_double_hyphen && arg == "--"
      return nil
    end
    # long option
    if longopts && arg.index("--") == 0
      optopt, optarg = arg[2..-1].split "=", 2

      if abbreviation
        abbr = longopts.collect { |o| o if o[0] =~ /^#{optopt}/ }.compact
        if abbr.empty?
          raise Getopt::UnknownOptionError.new optopt
        end
        if abbr.size == 1
          optopt = abbr.first.first
        elsif exact = abbr.find { |a| a[0] == optopt }
          optopt = exact.first
        else
          cands = abbr.collect { |o| o.first }
          raise Getopt::AmbiguousOptionError.new optopt, nil, cands
        end
      else
        unless longopts[optopt]
          raise Getopt::UnknownOptionError.new optopt
        end
      end

      case longopts[optopt]
      when :no_argument
        if optarg
          raise Getopt::ArgumentGivenError.new optopt
        end
        return [ optopt ]
      when :required_argument
        unless optarg
          optarg = argv.shift
          unless optarg
            raise Getopt::ArgumentRequiredError.new optopt
          end
        end
        if ! allow_empty_optarg && optarg.empty?
          raise Getopt::ArgumentRequiredError.new optopt
        end
        return [ optopt, optarg ]
      when :optional_argument
        if ! allow_empty_optarg && optarg && optarg.empty?
          raise Getopt::ArgumentRequiredError.new optopt
        end
        return [ optopt, optarg ]
      else
        raise ArgumentError,
              "wrong long option type - #{longopts[optopt].inspect}"
      end
      # NOTREACHED
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
    raise Getopt::UnknownOptionError.new optopt
  end

  if opts[pos.succ] == ":"
    if optional_short && opts[pos.succ.succ] == ":"
      # short option with optional argument
      optarg = arg.empty? ? nil : arg
      return [ optopt, optarg ]
    else
      # short option with required argument
      optarg = arg.empty? ? argv.shift : arg
      if optarg.nil? || (optarg.empty? && ! allow_empty_optarg)
        raise Getopt::ArgumentRequiredError.new optopt
      end
      return [ optopt, optarg ]
    end
  else
    # short option without argument
    unless arg.empty?
      argv.unshift "-#{arg}"
      argv.unshift :getopt_short if arg[0] == "-"
    end
    return [ optopt ]
  end

rescue Getopt::GetoptError => ex
  raise if use_exception

  if error_message
    if ex.option.length == 1
      warn "#{program_name}: #{ex.message} -#{ex.option}"
    else
      warn "#{program_name}: #{ex.message} --#{ex.option}"
    end
  end

  case ex
  when Getopt::UnknownOptionError
    return [ :unknown_option, ex.option ]
  when Getopt::ArgumentRequiredError
    return [ :argument_required, ex.option ]
  when Getopt::ArgumentGivenError
    return [ :argument_given, ex.option ]
  when Getopt::AmbiguousOptionError
    return [ :ambiguous_option, ex.option, ex.candidates ]
  end
end

Kernel.define_singleton_method "getopt", method(:getopt)

require "test/unit"
require "./trad-getopt.rb"

class Test_getopt < Test::Unit::TestCase

  test "empty argv" do
    av = []
    assert_equal nil, getopt(av, "a")
    assert_equal [], av
  end
  test "empty opts" do
    av = [ "a" ]
    assert_equal nil, getopt(av, "")
    assert_equal [ "a" ], av
  end
  test "nil opts" do
    av = [ "a" ]
    assert_equal nil, getopt(av, nil)
    assert_equal [ "a" ], av
  end

  test "stop at non option" do
    av = ["foo"]
    assert_equal nil, getopt(av, "-a")
    assert_equal ["foo"], av
  end
  test "unknown error" do
    av = [ "-x" ]
    $stderr = StringIO.new
    got = getopt(av, "a")
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [:unknown_option, "x"], got
    assert_equal "test.rb: unknown option - x\n", msg
    assert_equal [], av
  end

  test "short noarg" do
    av = [ "-a", "foo" ]
    assert_equal ["a"], getopt(av, "a")
    assert_equal ["foo"], av
  end

  test "short reqarg" do
    av = [ "-a", "foo" ]
    assert_equal ["a", "foo"], getopt(av, "a:")
    assert_equal [], av
  end
  test "short reqarg. error" do
    av = [ "-a" ]
    $stderr = StringIO.new
    got = getopt(av, "a:")
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [:argument_required, "a"], got
    assert_equal "test.rb: option requires an argument - a\n", msg
    assert_equal [], av
  end

  test "short optarg, with arg" do
    av = [ "-afoo" ]
    assert_equal ["a", "foo"], getopt(av, "a::")
    assert_equal [], av
  end
  test "short optarg, no arg" do
    av = [ "-a", "foo" ]
    assert_equal [ "a", nil ], getopt(av, "a::")
    assert_equal [ "foo" ], av
  end
  test "short optarg, no arg, at tail" do
    av = [ "-a" ]
    assert_equal [ "a", nil ], getopt(av, "a::")
    assert_equal [], av
  end
  test "short optarg, disabled" do
    av = [ "-a" ]
    $stderr = StringIO.new
    got = getopt(av, "a::", optional_short:false)
    $stderr = STDERR
    assert_equal [ :argument_required, "a"],  got
  end

  ### concatenation

  test "concat, noarg + noarg" do
    av = [ "-ab" ]
    opts = "ab"
    assert_equal ["a"], getopt(av, opts)
    assert_equal ["b"], getopt(av, opts)
  end
  test "concat, noarg + reqarg + arg" do
    av = [ "-abfoo" ]
    opts = "ab:"
    assert_equal ["a"], getopt(av, opts)
    assert_equal ["b", "foo"], getopt(av, opts)
  end

  ### special chars

  test "single `-'" do
    av = [ "-" ]
    assert_equal nil, getopt(av, "a")
    assert_equal ["-"], av
  end
  test "stop by `--'" do
    av = [ "--" ]
    assert_equal nil, getopt(av, "a")
    assert_equal [], av
  end

  test "stop_by_double_hyphen, disable" do
    av = [ "--" ]
    assert_equal [ "-" ], getopt(av, "-", stop_by_double_hyphen:false)
  end

  test "hyphen in concat, as option" do
    av = [ "-a-" ]
    opts = "a-"
    assert_equal ["a"], getopt(av, opts)
    assert_equal ["-"], getopt(av, opts)
    assert_equal [], av
  end
  test "hyphen in concat, not as option" do
    av = [ "-a-" ]
    opts = "a"
    assert_equal ["a"], getopt(av, opts)
    $stderr = StringIO.new
    got = getopt(av, opts)
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [:unknown_option, "-"],  got
    assert_equal "test.rb: unknown option - -\n", msg
    assert_equal [], av
  end

  test "colon as option" do
    av = [ "-:" ]
    assert_equal [":"],  getopt(av, ":a")
  end
  test "colon not as option" do
    av = [ "-:" ]
    $stderr = StringIO.new
    got = getopt(av, "a:")
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [:unknown_option, ":"],  got
    assert_equal "test.rb: unknown option - :\n", msg
    assert_equal [], av
  end

  ### keywords

  test "program_name" do
    av = [ "-x" ]
    $stderr = StringIO.new
    getopt(av, "a", error_message:true, program_name:"foo")
    msg = $stderr.string
    $stderr = STDERR
    assert_equal "foo: unknown option - x\n", msg
  end

  test "error_message" do
    av = [ "-x" ]
    $stderr = StringIO.new
    getopt(av, "a", error_message:false)
    msg = $stderr.string
    $stderr = STDERR
    assert_equal "", msg
  end

  test "use_exception, Getopt::UnknownOptionError" do
    av = [ "-x" ]
    begin
      getopt(av, "a", use_exception:true)
    rescue => ex
      assert_equal Getopt::UnknownOptionError, ex.class
      assert_equal "x", ex.option
      assert_equal "unknown option", ex.message
    end
  end
  test "use_exception, Getopt::ArgumentRequiredError" do
    av = [ "-a" ]
    begin
      getopt(av, "a:", use_exception:true)
    rescue => ex
      assert_equal Getopt::ArgumentRequiredError, ex.class
      assert_equal "a", ex.option
      assert_equal "option requires an argument", ex.message
    end
  end

  test "permute" do
    av = [ "foo", "-a", "bar" ]
    opts = "a"
    assert_equal ["a"],  getopt(av, opts, permute:true)
    assert_equal nil, getopt(av, opts, permute:true)
    assert_equal ["foo", "bar"], av
  end
  test "permute, reqarg" do
    av = [ "foo", "-a", "bar", "baz" ]
    opts = "a:"
    assert_equal ["a", "bar"],  getopt(av, opts, permute:true)
    assert_equal nil, getopt(av, opts, permute:true)
    assert_equal ["foo", "baz"], av
  end

  test "allow_empty_optarg" do
    av = [ "-a", "" ]
    opts = "a:"
    $stderr = StringIO.new
    assert_equal [:argument_required, "a"],  getopt(av, opts, allow_empty_optarg:false)
    $stderr = STDERR
  end
  test "allow_empty_optarg. long" do
    av = [ "--foo=" ]
    longopts = { "foo" => :required_argument }
    $stderr = StringIO.new
    assert_equal [:argument_required, "foo"],  getopt(av, "", longopts, allow_empty_optarg:false)
    $stderr = STDERR
  end
  test "allow_empty_optarg. long 2" do
    av = [ "--foo", "" ]
    longopts = { "foo" => :required_argument }
    $stderr = StringIO.new
    assert_equal [:argument_required, "foo"],  getopt(av, "", longopts, allow_empty_optarg:false)
    $stderr = STDERR
  end
  test "allow_empty_optarg. optional long" do
    av = [ "--foo=" ]
    longopts = { "foo" => :optional_argument }
    $stderr = StringIO.new
    assert_equal [:argument_required, "foo"],  getopt(av, "", longopts, allow_empty_optarg:false)
    $stderr = STDERR
  end

  ### short context

  test "short context" do
    av = [ "-a-" ]
    opts = "a"
    assert_equal [ "a" ], getopt(av, opts)
    $stderr = StringIO.new
    assert_equal [ :unknown_option, "-" ], getopt(av, opts)
    $stderr = STDERR
  end
  test "short context, not long option" do
    av = [ "-a-foo" ]
    opts = "afo-"
    lopts = {
      "foo" => :no_argument
    }
    assert_equal [ "a" ], getopt(av, opts, lopts)
    assert_equal [ "-" ], getopt(av, opts, lopts)
    assert_equal [ "f" ], getopt(av, opts, lopts)
  end
  test "short context, not long option, error" do
    av = [ "-a-foo" ]
    opts = "a-"
    lopts = {
      "foo" => :no_argument
    }
    assert_equal [ "a" ], getopt(av, opts, lopts)
    assert_equal [ "-" ], getopt(av, opts, lopts)
    $stderr = StringIO.new
    assert_equal [ :unknown_option, "f" ], getopt(av, opts, lopts)
    $stderr = STDERR
  end

  ### long option

  test "long option" do
    av = [ "--foo" ]
    opts = "fo-"
    lopts = {
      "foo" => :no_argument
    }
    assert_equal [ "foo" ], getopt(av, opts, lopts)
  end

  test "not long option" do
    av = [ "-foo" ]
    opts = "fo"
    lopts = {
      "foo" => :no_argument
    }
    assert_equal [ "f" ], getopt(av, opts, lopts)
    assert_equal [ "o" ], getopt(av, opts, lopts)
    assert_equal [ "o" ], getopt(av, opts, lopts)
  end

  test "wrong long option type" do
    av = [ "--foo" ]
    lopts = {
      "foo" => :bar
    }
    begin
      getopt(["--foo"], "", lopts)
    rescue => ex
      assert_equal ArgumentError, ex.class
      assert_equal [ "--foo" ], av
    end
  end
  test "wrong long option type, permute" do
    av = [ "a", "--foo", "b" ]
    lopts = {
      "foo" => :bar
    }
    begin
      getopt(["--foo"], "", lopts, permute:true)
    rescue => ex
      assert_equal ArgumentError, ex.class
      assert_equal [ "a", "--foo", "b" ], av
    end
  end

  test "unknown long option" do
    av = [ "--bar" ]
    lopts = {
      "foo" => :no_argument
    }
    $stderr = StringIO.new
    got = getopt(av, "", lopts)
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [ :unknown_option, "bar" ], got
    assert_equal "test.rb: unknown option - bar\n", msg
  end

  test "no_argument" do
    av = [ "--foo" ]
    lopts = {
      "foo" => :no_argument
    }
    assert_equal [ "foo" ], getopt(av, "", lopts)
  end
  test "no_argument, error" do
    av = [ "--foo=bar" ]
    lopts = {
      "foo" => :no_argument
    }
    $stderr = StringIO.new
    got = getopt(av, "", lopts)
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [ :argument_given, "foo" ], got
    assert_equal "test.rb: option doesn't take an argument - foo\n", msg
  end
  test "no_argument, exception" do
    av = [ "--foo=bar" ]
    lopts = {
      "foo" => :no_argument
    }
    begin
      getopt(av, "", lopts, use_exception:true)
    rescue => ex
      assert_equal Getopt::ArgumentGivenError, ex.class
      assert_equal "foo", ex.option
      assert_equal "option doesn't take an argument", ex.message
    end
  end

  test "required_argument" do
    av = [ "--foo=bar" ]
    lopts = {
      "foo" => :required_argument
    }
    assert_equal [ "foo", "bar" ], getopt(av, "", lopts)
  end
  test "required_argument, split" do
    av = [ "--foo", "bar" ]
    lopts = {
      "foo" => :required_argument
    }
    assert_equal [ "foo", "bar" ], getopt(av, "", lopts)
  end
  test "required_argument, empty arg" do
    av = [ "--foo=" ]
    lopts = {
      "foo" => :required_argument
    }
    assert_equal [ "foo", "" ], getopt(av, "", lopts)
  end
  test "required_argument, error" do
    av = [ "--foo" ]
    lopts = {
      "foo" => :required_argument
    }
    $stderr = StringIO.new
    got = getopt(av, "", lopts)
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [ :argument_required, "foo" ], got
    assert_equal "test.rb: option requires an argument - foo\n", msg
  end
  test "required_argument, exception" do
    av = [ "--foo" ]
    lopts = {
      "foo" => :required_argument
    }
    begin
      getopt(av, "", lopts, use_exception:true)
    rescue => ex
      assert_equal Getopt::ArgumentRequiredError, ex.class
      assert_equal "foo", ex.option
      assert_equal "option requires an argument", ex.message
    end
  end

  test "optional_argument, with arg" do
    av = [ "--foo=bar" ]
    lopts = {
      "foo" => :optional_argument
    }
    assert_equal [ "foo", "bar" ], getopt(av, "", lopts)
  end
  test "optional_argument, empty arg" do
    av = [ "--foo=" ]
    lopts = {
      "foo" => :optional_argument
    }
    assert_equal [ "foo", "" ], getopt(av, "", lopts)
  end
  test "optional_argument, no arg" do
    av = [ "--foo", "bar" ]
    lopts = {
      "foo" => :optional_argument
    }
    assert_equal [ "foo", nil ], getopt(av, "", lopts)
  end
  test "optional_argument, no arg, at tail" do
    av = [ "--foo" ]
    lopts = {
      "foo" => :optional_argument
    }
    assert_equal [ "foo", nil ], getopt(av, "", lopts)
  end

  test "unique abbrev, no candidates" do
    av = [ "--fo" ]
    lopts = {
      "foo" => :no_argument
    }
    assert_equal [ "foo" ], getopt(av, "", lopts)
  end
  test "unique abbrev" do
    av = [ "--foo-" ]
    lopts = {
      "foo" => :no_argument,
      "foo-bar" => :no_argument
    }
    assert_equal [ "foo-bar" ], getopt(av, "", lopts)
  end
  test "abbrev, exact match" do
    av = [ "--foo" ]
    lopts = {
      "foo" => :no_argument,
      "foo-bar" => :no_argument
    }
    assert_equal [ "foo" ], getopt(av, "", lopts)
  end
  test "abbrev, ambiguous" do
    av = [ "--foo" ]
    lopts = {
      "foo1" => :no_argument,
      "foo2" => :no_argument
    }
    $stderr = StringIO.new
    got = getopt(av, "", lopts)
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [ :ambiguous_option, "foo", ["foo1", "foo2"] ], got
    assert_equal "test.rb: ambiguos option (--foo1 --foo2) - foo\n", msg
  end
  test "abbrev, ambiguous, exception" do
    av = [ "--foo" ]
    lopts = {
      "foo1" => :no_argument,
      "foo2" => :no_argument
    }
    begin
      getopt(av, "", lopts, use_exception:true)
    rescue => ex
      assert_equal Getopt::AmbiguousOptionError, ex.class
      assert_equal "foo", ex.option
      assert_equal "ambiguos option (--foo1 --foo2)", ex.message
    end
  end

  test "abbrev disabled" do
    av = [ "--fo" ]
    lopts = {
      "foo" => :no_argument,
    }
    $stderr = StringIO.new
    got = getopt(av, "", lopts, abbreviation:false)
    msg = $stderr.string
    $stderr = STDERR
    assert_equal [ :unknown_option, "fo" ], got
    assert_equal "test.rb: unknown option - fo\n", msg
  end
end

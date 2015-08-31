typedef CmdOpts = {
  var f: String;
  var t: String;
  var i: String;
  var o: String;
  var l: Bool;
  var h: Bool;
}

class CLI {

  public function new() { }

  public function parseArgs() {
    var opts : CmdOpts = {h: false, t: "", i: "", o: "", l: false, f: ""};
    var handler = hxargs.Args.generate([
        @doc("Format to convert from")
        ["-f", "--from"] => function(format: String) { opts.f = format; },
        @doc("Format to convert to")
        ["-t", "--to"] => function(format: String) { opts.t = format; },
        @doc("Input file")
        ["-i", "--in"] => function(file: String) { opts.i = file; },
        @doc("Output file")
        ["-o", "--out"] => function(file: String) { opts.o = file; },
        @doc("List available format plugins")
        ["-l", "--list"] => function() { opts.l = true; },
        _ => function(arg:String) { opts.h = true; }
    ]);

    var args = Sys.args();
    if (args.length == 0) {
      opts.h = true;
    } else {
      handler.parse(args);
    }
    if (opts.h) {
      Sys.println(handler.getDoc());
    }
    return opts;
  }
  
  static public function main():Void {
    var a = sys.io.File.getContent("crossword.csv");
    var c = Converter.create("csv", "text");
    trace(c.convert(a));
    var cli = new CLI();
    var opts = cli.parseArgs();
    trace(opts);
  }
}

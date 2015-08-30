enum Cell {
  Black;
  Empty;
  Letter(c: String);
  Rebus(s: String, c: String);
}

typedef Border = {
  var left : Bool;
  var right : Bool;
  var top : Bool;
  var bottom : Bool;
}

class Square {
  public var contents : Cell;
  public var border : Border;
  public var number : Int;

  public function new(cell) {
    this.contents = cell;
  }

  public function black() : Bool {
    return this.contents == Black;
  }

  public function rebus() : Bool {
    return switch this.contents {
      case Rebus(_, _) : true;
      default : false;
    }
  }

  public function toString() : String {
    return switch this.contents {
      case Black: "#";
      case Empty: ".";
      case Letter(c): c;
      case Rebus(s, c): s;
    }
  }

  public function setFromString(c : String,
      opts : {black: String, empty: String, rebus: Bool}) {
    if (c == opts.black) {
      this.contents = Black;
    } else if (c == opts.empty || c == '') {
      this.contents = Empty;
    } else if (c.length > 1 && opts.rebus) {
      this.contents = Rebus(c, c.charAt(0));
    } else {
      // If we have multiple chars but opts.rebus = false, strip off non-alpha
      // chars first, then take the first remaining one.
      var clean = ~/[^A-Za-z]/g.replace(c, '');
      this.contents = Letter(clean.charAt(0));
    }
  }
}

typedef Strings = Array<String>;
typedef Array2D<T> = Array<Array<T>>;
typedef Grid = Array2D<Square>;

typedef ClueNumbers = { across : Array<Int>, down : Array<Int> }

typedef Clues = { across : Strings, down : Strings }

class XWord {
  public var height : Int;
  public var width : Int;
  public var grid : Grid;
  public var clues: Clues;

  public function new(h: Int, w: Int) {
    this.height = h;
    this.width = w;
    this.grid = [for (y in 0 ... h) [for (x in 0 ... w) new Square(Empty)]];
    this.clues = { across : [], down : [] };
  }

  public function map<T>(f : Square -> T) : Array2D<T> {
    return [for (y in 0 ... height)
      [for (x in 0 ... width)
        f(grid[y][x])]];
  }

  public function inspect() {
    for (y in 0 ... height) {
      for (x in 0 ... width) {
        Sys.print(grid[y][x].toString());
      }
      Sys.println("");
    }
  }

  // Clue numbering
  function black(x: Int, y: Int) : Bool {
    return grid[y][x].black();
  }

  function boundary(x: Int, y: Int) : Bool {
    return (x < 0) || (y < 0) ||
      (x >= width) || (y >= height) ||
      black(x, y);
  }

  function across(x: Int, y: Int) : Bool {
    return boundary(x - 1, y) && !boundary(x, y) && !boundary(x + 1, y);
  }

  function down(x: Int, y: Int) : Bool {
    return boundary(x, y - 1) && !boundary(x, y) && !boundary(x, y + 1);
  }

  public function number() : ClueNumbers {
    var n = 1;
    var ac = [];
    var dn = [];
    for (y in (0 ... height)) {
      for (x in (0 ... width)) {
        var added = false;
        if (across(x, y)) {
          ac.push(n);
          added = true;
        }
        if (down(x, y)) {
          dn.push(n);
          added = true;
        }
        if (added) {
          grid[y][x].number = n;
          n++;
        }
      }
    }
    return { across: ac, down: dn };
  }

  static public function main():Void {
    var a = new XWord(8, 5);
    a.inspect();
    var nums = a.number();
    var out = a.map(function(s) {
      var n = (s.number > 0) ? "" + s.number : "";
      return StringTools.lpad(n, " ", 2) + s.toString();
    });

    for (row in out) {
      for (c in row) {
        Sys.print(c);
      }
      Sys.println("");
    }
    Sys.println(nums);
  }
}

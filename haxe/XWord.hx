enum Cell {
  Black;
  Empty;
  Letter(c: String);
  Rebus(s: String, c: String);
}

class Border {
  var left : Bool;
  var right : Bool;
  var top : Bool;
  var bottom : Bool;
}

class Square {
  public var contents : Cell;
  public var border : Border;

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
}

class XWord {
  var height : Int;
  var width : Int;
  var grid : Array< Array<Square> >;

  public function new(h: Int, w: Int) {
    this.height = h;
    this.width = w;
    this.grid = [for (y in 0 ... h) [for (x in 0 ... w) new Square(Empty)]];
  }

  public function inspect() {
    for (y in 0 ... this.height) {
      for (x in 0 ... this.width) {
        Sys.print(grid[y][x].toString());
      }
      Sys.println("");
    }
  }

  static public function main():Void {
    var a = new XWord(8, 5);
    a.inspect();
  }
}

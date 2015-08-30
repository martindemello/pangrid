import format.csv.Reader;

class CSV implements Converter.XwReader {
  public function read(data : String) : XWord {
    var s = Reader.parseCsv(data);
    var r = ~/^width:/i;
    while (!(~/^width:/i).match(s[0][0])) {
      s.shift();
    }

    var h = s.shift();
    var header = new Map();
    for (c in h) {
      var kv = ~/:\s+/.split(c);
      var key = kv[0].toLowerCase();
      header[key] = kv[1];
    }

    var w = Std.parseInt(header['width']);
    var h = Std.parseInt(header['height']);
    var o = Std.parseInt(header['offset']);
    var xw = new XWord(w, h);

    // Read in grid
    var opts = {black : header['black'], empty : header['empty'], rebus : false}
    for (y in 0 ... h) {
      var row = s.shift();
      for (x in 0 ... w) {
        xw.grid[y][x].setFromString(row[o + x], opts);
      }
    }

    // Read in clues
    var clues = [];
    var cr = Std.parseInt(header['clues']);
    for (row in s) {
      if (row[cr] != '') {
        clues.push(row[cr]);
      }
    }

    var nums = xw.number();
    var n_across = nums.across.length;
    for (i in 0 ... (n_across - 1)) {
      xw.clues.across.push(clues[i]);
    }
    for (i in n_across ... (clues.length - 1)) {
      xw.clues.down.push(clues[i]);
    }
    return xw;
  }

  public function new() { }
  
  static public function main():Void {
    var a = sys.io.File.getContent("crossword.csv");
    var r = new CSV();
    var xw = r.read(a);
    var t = new Text();
    Sys.print(t.write(xw));
  }
}

using ArrayFormatter;

class Text implements Converter.XwWriter {
  public function new() { }

  public function write(xw : XWord) : String {
    var nums = xw.number();
    var rows = xw.map(function(f) { return f.toString(); });
    var grid = [for (row in rows) row.join("")].toLines();
    var ac = formatClues(nums.across, xw.clues.across, 2);
    var dn = formatClues(nums.down, xw.clues.down, 2);
    return '$grid\nAcross:\n$ac\nDown:\n$dn';
  }

  function formatClues(numbers : Array<Int>, clues: Array<String>, indent: Int) {
    // assert numbers.length == clues.length
    var n = numbers.length - 1;
    var row = [for (i in 0 ... n) '${numbers[i]}. ${clues[i]}'];
    return row.indent(indent).toLines();
  }
}

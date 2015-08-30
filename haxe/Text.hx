using StringTools;

class Text {
  public function new() { }

  public function write(xw : XWord) : String {
    var nums = xw.number();
    var rows = xw.map(function(f) { return f.toString(); });
    var grid = [for (row in rows) row.join("")].join("\n");
    var ac = format_row(nums.across, xw.clues.across, 2);
    var dn = format_row(nums.down, xw.clues.down, 2);
    return '$grid\n\nAcross:\n$ac\n\nDown:\n$dn\n';
  }

  function format_row(numbers : Array<Int>, clues: Array<String>, indent: Int) {
    // assert numbers.length == clues.length
    var n = numbers.length - 1;
    var row = [for (i in 0 ... n)
      "".lpad(" ", indent) + '${numbers[i]}. ${clues[i]}'];
    return row.join("\n"); 
  }
}

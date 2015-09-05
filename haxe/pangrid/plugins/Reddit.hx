package pangrid.plugins;

using StringTools;
using pangrid.lib.ArrayFormatter;
import pangrid.lib.Converter;
import pangrid.lib.XWord;

class Reddit implements Converter.XwWriter {
  public function new() { }

  public function write(xw : XWord) : String {
    var nums = xw.number();
    var grid = formatGrid(xw);

    var ac = formatClues(nums.across, xw.clues.across, 2);
    var dn = formatClues(nums.down, xw.clues.down, 2);
    return '$grid\n\n**Across**\n\n$ac\n\n**Down**\n\n$dn\n';
  }

  function formatGrid(xw : XWord) : String {
    var rows = xw.toArray({black: '*.*', empty: ' '}, function(s) {
      return (s.number > 0) ? '^${s.number}' : '';
    });
    var lines = [for (row in rows) row.fence('|')];
    var sep = [for (i in 0 ... xw.width) "--"].join('');
    var first = lines.shift();
    var out = [first, sep].concat(lines);
    return out.toLines();
  }

  function formatClues(numbers : Array<Int>, clues: Array<String>, indent: Int) {
    // assert numbers.length == clues.length
    var n = numbers.length - 1;
    var row = [for (i in 0 ... n) '${numbers[i]}. ${clues[i]}'];
    return row.indent(indent).join("\n"); 
  }
}


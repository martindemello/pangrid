package pangrid.lib;

using StringTools;
import pangrid.lib.Types;

class ArrayFormatter {
  public static function indent(xs: Strings, n: Int) : Strings {
    var pad = ''.lpad(" ", n);
    return [for (x in xs) pad + x];
  }

  public static function fence(xs: Strings, s: String) : String {
    return s + xs.join(s) + s;
  }

  public static function toLines(xs: Strings) : String {
    return xs.join("\n") + "\n";
  }
}

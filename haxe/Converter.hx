interface XwReader {
  public function read(data : String) : XWord;
}

interface XwWriter {
  public function write(xw : XWord) : String;
}

interface Converter extends XwReader extends XwWriter { }

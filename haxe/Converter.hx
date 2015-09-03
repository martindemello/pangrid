interface XwReader {
  public function read(data : String) : XWord;
}

interface XwWriter {
  public function write(xw : XWord) : String;
}

typedef Factory<T> = Map<String, Void -> T>;

class Converter {
  var reader : XwReader;
  var writer : XwWriter;

  static var readers : Factory<XwReader> = [
    "csv" => function() { return new CSV(); },
  ];

  static var writers : Factory<XwWriter> = [
    "text" => function() { return new Text(); },
    "reddit" => function() { return new Reddit(); }
  ];

  static function get<T>(name: String, factory: Factory<T>) : T {
    var f = factory.get(name);
    if (f == null) {
      throw 'bad plugin: ${name}';
    }
    return f();
  }

  static function getReader(name: String) {
    return get(name, readers);
  }

  static function getWriter(name: String) {
    return get(name, writers);
  }

  public static function list() {
    var r = [for (k in readers.keys()) k]; 
    var w = [for (k in writers.keys()) k];
    return { readers: r, writers: w };
  }

  public static function create(reader: String, writer: String) : Converter {
    var r = getReader(reader);
    var w = getWriter(writer);
    return new Converter(r, w);
  }

  public function new(r : XwReader, w : XwWriter) {
    this.reader = r;
    this.writer = w;
  }

  public function convert(data : String) : String {
    var xw = reader.read(data);
    return writer.write(xw);
  }
}

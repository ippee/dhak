import 'dart:convert';
import 'dart:io';

import 'package:dhak/config/preset.dart';

class Config {
  late final file;
  late Map<String, dynamic> _doc;

  Config(String path) {
    this.file = File(path);

    if (!this.file.existsSync()) {
      print('"$path" was not found.');
      print('Creating "$path" now...');
      var json = Config._stringConfig();
      this.file.writeAsStringSync(json);
      print('Finished!\n');
    }

    var contents = this.file.readAsStringSync();
    this._doc = json.decode(contents);
  }

  dynamic doc() {
    return this._doc;
  }

  void setPresets(Preset preset) {
    this._doc['presets'][preset.name()] = {
      'password_length': preset.passLength(),
      'symbols': preset.symbols(),
      'salt': preset.salt()
    };
  }

  void write() {
    var encoder = JsonEncoder.withIndent('  ');
    var contents = encoder.convert(this._doc);
    this.file.writeAsStringSync(contents);
  }

  static String _stringConfig() {
    return r'''{
  "presets": {
    "default": {
      "password_length": 20,
      "symbols": [
        "/",
        "#",
        "%",
        "&",
        "@",
        "+",
        "-",
        "_"
      ],
      "algorithm": "2b",
      "cost": "10"
    }
  }
}''';
  }
}

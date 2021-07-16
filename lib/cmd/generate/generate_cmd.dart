import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_clipboard/dart_clipboard.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:dhak/cmd/cmd.dart';
import 'package:dhak/cmd/generate/password_operator.dart';
import 'package:dhak/cmd/generate/password_status.dart';
import 'package:dhak/config/config.dart';
import 'package:dhak/config/preset.dart';
import 'package:dhak/util/dhak_exception.dart';
import 'package:dhak/util/hidden_input.dart';

class GenerateCmd extends Cmd {
  final String title;
  final String presetName;
  final String option;
  String passPhrase;
  late String path;

  GenerateCmd(this.title, this.presetName, this.option,
      [this.passPhrase = '', this.path = '']) {
    if (this.path == '') {
      Map<String, String> env = Platform.environment;

      if (Platform.isWindows) {
        this.path = '${env['UserProfile']!}/.dhakrc';
      } else if (Platform.isMacOS || Platform.isLinux) {
        this.path = '${env['HOME']!}/.dhakrc';
      } else {
        throw DhakRuntimeException(
            'Platform error: "${Platform.operatingSystem}" is not supported.');
      }
    }
  }

  @override
  void run() {
    if (this.passPhrase == '') {
      this.passPhrase = HiddenInput.readPassword('Passphrase: ');
    }

    PasswordStatus status;

    status = PasswordStatus(passPhrase);
    if (!status.isSecure()) {
      print('WARNING: The passphrase you entered was not secure. '
          'A passphrase should have length of 8 or more and contain at least one lower-case, upper-case and number.\n');
    }

    // The countermeasure for the total length with the passphrase and the title
    // which exceeds 72.
    // The hash length of SHA512 in strings is 128, so its 56 characters will be
    // cut down when it is taken as the argument of BCrypt. However, hashing them
    // will prevent the loss of the two pieces of information.
    final bytes = utf8.encode(this.passPhrase + this.title);
    final target = sha512.convert(bytes).toString();

    final config = Config(this.path);
    final preset =
        Preset.newInstance(this.presetName, config.doc(), target.hashCode);

    var password = this._genPassword(target, config, preset);
    status = PasswordStatus(password);
    final rnd = Random(password.hashCode);
    while (!status.isSecure()) {
      var num = rnd.nextInt(100);
      password = this._genPassword('$num$target', config, preset);
      status = PasswordStatus(password);
    }

    final clipboard = Clipboard();
    clipboard.setContents(password);

    print('Password was copied to clipboard!');
    if (this.option.contains('d')) {
      print('Password: $password');
    }
  }

  String _genPassword(String target, Config config, Preset preset) {
    var reversed = '';
    var encrypted = target;
    var len = preset.passLength();
    while (reversed.length < len) {
      encrypted = DBCrypt().hashpw(encrypted, preset.salt());
      for (var i = encrypted.length - 1; 29 <= i; i--) {
        reversed += encrypted[i];
      }
    }

    var password = reversed.substring(0, len);
    final operator = PasswordOperator(password);
    if (preset.symbols().length != 0) {
      password = operator.replaceAtRandomWith(preset.symbols());
    } else {
      password = operator.replaceSymbols();
    }

    return password;
  }
}

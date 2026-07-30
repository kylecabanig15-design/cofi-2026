import 'dart:io';

void main() {
  var file = File('lib/features/home/profile_tab.dart');
  var content = file.readAsStringSync();
  
  int balance = 0;
  for (int i = 0; i < content.length; i++) {
    if (content[i] == '(') balance++;
    if (content[i] == ')') balance--;
  }
  
  print('Parens balance: $balance');
  
  if (balance < 0) {
    // Too many closing parens. Let's remove them from the end.
    var lines = content.split('\n');
    int toRemove = -balance;
    for (int i = lines.length - 1; i >= 0 && toRemove > 0; i--) {
      if (lines[i].trim() == '),') {
        lines[i] = '';
        toRemove--;
      }
    }
    file.writeAsStringSync(lines.join('\n'));
    print('Removed ${-balance} closing parens.');
  }
}

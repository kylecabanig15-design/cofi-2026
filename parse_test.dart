import 'dart:io';
void main() {
  final content = File('lib/features/home/profile_tab.dart').readAsStringSync();
  int parens = 0;
  int brackets = 0;
  int braces = 0;
  for (int i = 0; i < content.length; i++) {
    if (content[i] == '(') parens++;
    if (content[i] == ')') parens--;
    if (content[i] == '[') brackets++;
    if (content[i] == ']') brackets--;
    if (content[i] == '{') braces++;
    if (content[i] == '}') braces--;
  }
  print("Final parens: $parens, brackets: $brackets, braces: $braces");
}

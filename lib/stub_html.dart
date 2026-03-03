// stub_html.dart
// Stub untuk dart:html agar tidak error saat build di Android/Windows
// File ini tidak melakukan apa-apa

class _Window {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  dynamic callMethod(String method, [List? args]) => null;
}

final window = _Window();

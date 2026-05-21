String? normalizeProId(Object? value) {
  if (value == null) {
    return null;
  }

  var text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  if (text.endsWith('.0')) {
    text = text.substring(0, text.length - 2);
  }
  text = text.replaceAll(RegExp(r'\s+'), '');

  if (text.isEmpty) {
    return null;
  }
  return text;
}

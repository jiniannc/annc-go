String normalizeConditionTag(String? raw) {
  if (raw == null) {
    return '';
  }
  var tag = raw.trim().toLowerCase();
  if (tag.isEmpty) {
    return '';
  }

  tag = tag.replaceAll(RegExp(r'[\s\-]+'), '_');
  tag = tag.replaceAll(RegExp(r'_+'), '_');

  if (tag.startsWith('is_specialwelcome') &&
      !tag.startsWith('is_specialwelcome_')) {
    tag = tag.replaceFirst('is_specialwelcome', 'is_specialwelcome_');
  }

  return tag;
}

bool isNoneLikeConditionTag(String? raw) {
  final normalized = normalizeConditionTag(raw);
  return normalized.isEmpty || normalized == 'none';
}

bool isSpecialWelcomeTag(String? raw) {
  final normalized = normalizeConditionTag(raw);
  return normalized.startsWith('is_specialwelcome_');
}

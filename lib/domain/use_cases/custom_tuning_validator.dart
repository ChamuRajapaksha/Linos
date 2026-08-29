import '../../domain/models/note.dart';

class CustomTuningValidation {
  const CustomTuningValidation({
    required this.isValid,
    this.nameError,
    this.stringErrors = const {},
  });

  final bool isValid;
  final String? nameError;

  /// Per-string-index validation error messages (empty map when all valid).
  final Map<int, String> stringErrors;
}

class CustomTuningValidator {
  /// Standard six-string guitar supports exactly this many strings.
  static const int stringCount = 6;

  /// Reasonable playable octave range for a guitar's open strings.
  static const int minOctave = 0;
  static const int maxOctave = 6;

  static CustomTuningValidation validate({
    required String name,
    required List<Note> notes,
  }) {
    String? nameError;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      nameError = 'Enter a tuning name.';
    } else if (trimmed.length > 24) {
      nameError = 'Keep the name under 24 characters.';
    }

    if (notes.isEmpty) {
      return CustomTuningValidation(isValid: false, nameError: nameError);
    }

    if (notes.length != stringCount) {
      return CustomTuningValidation(
        isValid: false,
        nameError: nameError,
        stringErrors: {
          notes.isEmpty
              ? 0
              : notes.length.clamp(0, notes.length - 1): 'A custom tuning must '
                  'have exactly 6 strings.',
        },
      );
    }

    final Map<int, String> stringErrors = {};
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final index = Note.chromaticNotes.indexOf(note.name);
      if (index < 0) {
        stringErrors[i] = 'Not a valid note name.';
      }
      if (note.octave < minOctave || note.octave > maxOctave) {
        stringErrors[i] = 'Octave out of range.';
      }
    }

    return CustomTuningValidation(
      isValid: nameError == null && stringErrors.isEmpty,
      nameError: nameError,
      stringErrors: stringErrors,
    );
  }
}

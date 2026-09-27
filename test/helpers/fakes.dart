import 'package:mocktail/mocktail.dart';
import 'package:teachme/models/phrase.dart';

class FakePhrase extends Fake implements Phrase {}

void registerFallbackValues() {
  registerFallbackValue(FakePhrase());
}

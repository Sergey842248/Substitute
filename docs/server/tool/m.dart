import 'package:substitute_sync_server/src/moderation.dart';
void main() {
  for (final n in ['Scheißkopf','Scheisskopf','Arschloch','Frau Muster']) {
    final c = Moderation.checkDisplayName(n);
    print('"$n" ok=${c.isOk} p=${c.problem} term=${c.term} norm="${Moderation.normalize(n)}"');
  }
  print('compoundTerms has scheiss: ${Moderation.compoundTerms.map(Moderation.normalize)}');
}

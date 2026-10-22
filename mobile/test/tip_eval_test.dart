// Reconnaissance des équipes et calcul des résultats : mêmes cas que kounadia-engine/scripts/settle.mjs.
import 'package:flutter_test/flutter_test.dart';
import 'package:kounadia/services/tip_eval.dart';

void main() {
  test('mêmes matchs malgré des noms différents', () {
    expect(matchSim('Atlético Madrid', 'Real Sociedad', 'Atletico de Madrid', 'Real Sociedad'), greaterThan(0.6));
    expect(matchSim('Man Utd', 'Chelsea', 'Manchester United', 'Chelsea FC'), greaterThan(0.6));
    expect(matchSim('Paris Saint-Germain', 'Lyon', 'Paris SG', 'Olympique Lyonnais'), greaterThan(0));
    expect(matchSim('Inter', 'Milan', 'Inter Milan', 'AC Milan'), greaterThan(0));
    expect(matchSim('Al Hilal', 'Al Nassr', 'Al-Hilal SFC', 'Al Nassr'), greaterThan(0));
    expect(teamSim('Bayern München', 'Bayern Munich'), greaterThanOrEqualTo(0.5));
  });

  test('matchs différents refusés', () {
    expect(matchSim('Arsenal', 'Chelsea', 'Chelsea', 'Arsenal'), 0);
    expect(matchSim('Real Madrid', 'Barcelona', 'Real Betis', 'Barcelona'), 0);
  });

  test('résultat des pronostics écrits en français', () {
    expect(evalTip('Victoire Man Utd', 'Manchester United', 'Chelsea', 2, 1), true);
    expect(evalTip('Chelsea ou nul', 'Manchester United', 'Chelsea', 1, 1), true);
    expect(evalTip('Plus de 2,5 buts', 'A', 'B', 2, 1), true);
    expect(evalTip('Les deux équipes marquent : non', 'A', 'B', 1, 0), true);
    expect(evalTip('Victoire Arsenal', 'Manchester United', 'Chelsea', 1, 0), isNull);
    expect(evalTip('Victoire Manchester City', 'Manchester United', 'Manchester City', 0, 2), true);
  });
}

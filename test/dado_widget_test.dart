import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/dado_widget.dart';

void main() {
  testWidgets('ParDadosWidget muestra los dos dados de la tirada', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParDadosWidget(
            dados: const [2, 6],
            numeroSeleccionado: null,
            seleccionHabilitada: true,
            onSeleccionar: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(DadoWidget), findsNWidgets(2));
  });

  testWidgets('sin dados todavia no muestra ningun dado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParDadosWidget(
            dados: null,
            numeroSeleccionado: null,
            seleccionHabilitada: true,
            onSeleccionar: null,
          ),
        ),
      ),
    );

    expect(find.byType(DadoWidget), findsNothing);
  });

  testWidgets('tocar un dado llama a onSeleccionar con su valor', (tester) async {
    int? seleccionado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParDadosWidget(
            dados: const [2, 6],
            numeroSeleccionado: null,
            seleccionHabilitada: true,
            onSeleccionar: (valor) => seleccionado = valor,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DadoWidget).first);
    expect(seleccionado, 2);
  });

  testWidgets('el dado seleccionado se ve distinto (mas grande) que el otro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParDadosWidget(
            dados: const [2, 6],
            numeroSeleccionado: 2,
            seleccionHabilitada: true,
            onSeleccionar: (_) {},
          ),
        ),
      ),
    );

    final escalas = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).toList();
    expect(escalas[0].scale, greaterThan(escalas[1].scale));
  });

  testWidgets('deshabilitado no responde al toque', (tester) async {
    int? seleccionado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParDadosWidget(
            dados: const [2, 6],
            numeroSeleccionado: null,
            seleccionHabilitada: false,
            onSeleccionar: (valor) => seleccionado = valor,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DadoWidget).first);
    expect(seleccionado, isNull);
  });
}

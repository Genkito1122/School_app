import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/auth/Auth.dart';

void main() {
  group('Виджет-тест валидации данных при авторизации', () {
    
    testWidgets('T-001: Валидация показывает ошибку при пустых полях входа', 
        (WidgetTester tester) async {
      // Arrange - запускаем экран аутентификации
      await tester.pumpWidget(const MaterialApp(home: Auth()));
      
      print('🚀 Экран аутентификации запущен');

      // Act - нажимаем кнопку "Войти" без заполнения полей
      await tester.tap(find.text('Войти'));
      await tester.pump(); // Ждем обновления состояния

      // Assert - проверяем появление сообщения об ошибке
      expect(find.text('Заполните все поля'), findsOneWidget);
      
      print('✅ Ошибка "Заполните все поля" отображается корректно');
    });

    testWidgets('T-002: Валидация показывает ошибку при пустом логине', 
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(home: Auth()));

      // Act - заполняем только пароль
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Войти'));
      await tester.pump();

      // Assert
      expect(find.text('Заполните все поля'), findsOneWidget);
      
      print('✅ Ошибка отображается при пустом логине');
    });

    testWidgets('T-003: Валидация показывает ошибку при пустом пароле', 
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(home: Auth()));

      // Act - заполняем только логин
      await tester.enterText(find.byType(TextField).at(0), 'testuser');
      await tester.tap(find.text('Войти'));
      await tester.pump();

      // Assert
      expect(find.text('Заполните все поля'), findsOneWidget);
      
      print('✅ Ошибка отображается при пустом пароле');
    });

    testWidgets('T-004: Сообщение об ошибке исчезает после заполнения полей', 
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(home: Auth()));

      // Act 1 - вызываем ошибку пустых полей
      await tester.tap(find.text('Войти'));
      await tester.pump();
      
      // Assert 1 - ошибка присутствует
      expect(find.text('Заполните все поля'), findsOneWidget);

      // Act 2 - заполняем поля
      await tester.enterText(find.byType(TextField).at(0), 'testuser');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.pump();

      // Assert 2 - ошибка исчезает
      expect(find.text('Заполните все поля'), findsNothing);
      
      print('✅ Сообщение об ошибке исчезает после заполнения полей');
    });

    testWidgets('T-005: Кнопка входа активна при заполненных полях', 
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(home: Auth()));

      // Act - заполняем оба поля
      await tester.enterText(find.byType(TextField).at(0), 'testuser');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.pump();

      // Assert - кнопка должна быть активна
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevatedButton.enabled, isTrue);
      
      print('✅ Кнопка входа активна при заполненных полях');
    });
  });
}
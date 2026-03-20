@echo off
set FIREBASE_CONFIG=lib\firebase_options.dart

echo Проверка конфигурации...
if not exist "%FIREBASE_CONFIG%" (
    echo Ошибка: Файл firebase_options.dart не найден.
    echo Выполните настройку FlutterFire CLI.
    exit /b 1
)

echo Установка зависимостей...
call flutter pub get

echo Запуск приложения...
call flutter run

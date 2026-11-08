@echo off
echo [CIVITAS] Iniciando automatizacion y preparacion para la defensa...
cd /d "C:\Users\felip\Desktop\PROYECTO CIVITAS"
flutter pub get
flutter analyze
echo [CIVITAS] Entorno verificado y listo.
pause

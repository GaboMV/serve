# Imagen oficial de Dart
FROM dart:stable

# Directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias primero (cache)
COPY pubspec.* ./

# Instalar dependencias
RUN dart pub get

# Copiar todo el proyecto
COPY . .

# Exponer puerto (Render usará PORT)
EXPOSE 3003

# Comando para ejecutar el servidor
CMD ["dart", "run", "bin/servidor.dart"]

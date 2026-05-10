# Usamos la imagen de Java 21 que ya tienes
FROM eclipse-temurin:21-jdk

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiamos el archivo JAR generado por Maven
# Usamos un comodín (*) por si el nombre tiene versiones
COPY target/*.jar app.jar

# EXPOSE es informativo, aquí ponemos el 8085 que usa tu app
EXPOSE 8085

# Comando para arrancar el microservicio
ENTRYPOINT ["java", "-jar", "app.jar"]
# build using "docker build ./ -t tiny-java --build-arg VERSION=1.2.3.4"
# run using docker run -p 8080:8080 docker.io/library/tiny-java -e SPRING_PROFILES_ACTIVE=local
###############################################################################################
# build stage
# Works well with "FROM openjdk:11-slim as build",
# - however, this image is optimized by Java on Azure team
FROM mcr.microsoft.com/openjdk/jdk:11-ubuntu as build

VOLUME /tmp
WORKDIR /
COPY .mvn .mvn
COPY mvnw .
COPY pom.xml .

RUN ./mvnw -B dependency:go-offline --quiet

ENV SPRING_PROFILES_ACTIVE=local
ENV JAVA_OPTS=-Dspring.profiles.active=local
ENV PORT=80

COPY src src

RUN ./mvnw -B package

RUN mv ./target/todo-*.jar "./target/todo-app.jar"

# package stage
# For debugging, bash and curl, use FROM openjdk:11-jre-slim as runtime
# FROM mcr.microsoft.com/openjdk/jdk:11-distroless as runtime
FROM openjdk:11-jre-slim-buster as runtime

ARG VERSION

WORKDIR /

COPY --from=build ./target/todo-app.jar /todo-app.jar

EXPOSE 80
EXPOSE 443

CMD ["-jar", "/todo-app.jar"]
#The distroless images are based on the CBL-Mariner 2.0 distribution by Microsoft.
#The ENTRYPOINT of these images is already configured pointing to the java command.
#Consuming Dockerfiles must use the CMD instruction to complete the command-line arguments of the JVM launcher process.
#ENTRYPOINT ["java", "-jar", "/todo-app.jar" ]
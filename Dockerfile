# 构建阶段
FROM maven:3.8.6-openjdk-8 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests -pl eladmin-system -am

# 运行阶段  
FROM openjdk:8-jdk-slim
WORKDIR /app
COPY --from=build /app/eladmin-system/target/eladmin-system-*.jar app.jar
EXPOSE 8000
ENTRYPOINT ["java", "-jar", "app.jar"]
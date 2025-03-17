# ELADMIN 二次开发设计文档

## 1. 项目概述
ELADMIN 是一个基于 Spring Boot 的后台管理系统，包含多个模块，如系统管理、权限管理、代码生成等。本文档旨在提供详细的开发环境设置、启动步骤以及容器化部署方案。

## 2. 开发环境设置
### 2.1 Java 版本
- JDK 8 (1.8)

### 2.2 构建工具
- Maven 3.8+

### 2.3 数据库
- MySQL 8.0
- Redis 6.0

### 2.4 安装步骤
1. **安装 JDK**
   ```sh
   sdk install java 8.0.362
   ```

2. **安装 Maven**
   ```sh
   sdk install maven 3.8.6
   ```

3. **下载并安装 MySQL 和 Redis**

## 3. 项目启动
### 3.1 本地启动
1. **启动 MySQL 和 Redis**
   ```sh
   docker-compose up -d
   ```

2. **启动应用**
   ```sh
   cd eladmin-system
   mvn spring-boot:run
   ```

### 3.2 容器化启动
1. **构建镜像**
   ```sh
   docker-compose build
   ```

2. **启动容器**
   ```sh
   docker-compose up -d
   ```

## 4. 容器化部署方案
### 4.1 docker-compose.yml
```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: eladmin-mysql
    environment:
      MYSQL_ROOT_PASSWORD: root123
      MYSQL_DATABASE: eladmin
      TZ: Asia/Shanghai
    volumes:
      - mysql_data:/var/lib/mysql
      - ./sql:/docker-entrypoint-initdb.d
    ports:
      - "3306:3306"
    networks:
      - eladmin-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 10s
      retries: 10

  redis:
    image: redis:6.0-alpine
    container_name: eladmin-redis
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - eladmin-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 10s
      retries: 5

  app:
    build: .
    container_name: eladmin-app
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "8000:8000"
    environment:
      SPRING_PROFILES_ACTIVE: prod
      TZ: Asia/Shanghai
    networks:
      - eladmin-net
    restart: unless-stopped

volumes:
  mysql_data:
  redis_data:

networks:
  eladmin-net:
    driver: bridge
```

### 4.2 Dockerfile
```dockerfile
# 构建阶段
FROM maven:3.8.6-openjdk-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests -pl eladmin-system -am

# 运行阶段  
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY --from=build /app/eladmin-system/target/eladmin-system-*.jar app.jar
EXPOSE 8000
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## 5. 二次开发指南
### 5.1 模块扩展
- 新增业务模块需继承`eladmin-common`基础配置
- REST API遵循`/api/[模块名]/v1/`版本规范

### 5.2 新增业务模块的具体步骤
1. **创建新模块目录**
   在`eladmin-system/src/main/java/me/zhengjie/modules`目录下创建新模块目录，例如`custom-module`。

2. **创建模块配置文件**
   在新模块目录下创建`CustomModuleConfig.java`文件，配置模块的基本信息和依赖。

   ```java
   package me.zhengjie.modules.custom_module.config;

   import org.springframework.context.annotation.Configuration;
   import org.springframework.context.annotation.Import;

   @Configuration
   @Import({CustomModuleService.class})
   public class CustomModuleConfig {
   }
   ```

3. **创建服务类**
   在新模块目录下创建`CustomModuleService.java`文件，实现业务逻辑。

   ```java
   package me.zhengjie.modules.custom_module.service;

   import org.springframework.stereotype.Service;

   @Service
   public class CustomModuleService {
       public String getMessage() {
           return "Hello from Custom Module!";
       }
   }
   ```

4. **创建控制器**
   在新模块目录下创建`CustomModuleController.java`文件，定义REST API接口。

   ```java
   package me.zhengjie.modules.custom_module.controller;

   import me.zhengjie.modules.custom_module.service.CustomModuleService;
   import org.springframework.beans.factory.annotation.Autowired;
   import org.springframework.web.bind.annotation.GetMapping;
   import org.springframework.web.bind.annotation.RequestMapping;
   import org.springframework.web.bind.annotation.RestController;

   @RestController
   @RequestMapping("/api/custom_module/v1")
   public class CustomModuleController {

       @Autowired
       private CustomModuleService customModuleService;

       @GetMapping("/message")
       public String getMessage() {
           return customModuleService.getMessage();
       }
   }
   ```

5. **更新数据库配置**
   如果新模块需要数据库表，需在`sql/eladmin.sql`中添加相应的表结构，并在`application-dev.yml`或`application-prod.yml`中配置数据源。

6. **测试新模块**
   启动应用后，访问`http://localhost:8000/api/custom_module/v1/message`，确认返回`Hello from Custom Module!`。

### 5.3 REST API 的详细规范
- **版本控制**：所有API需遵循`/api/[模块名]/v1/`的版本规范。
- **请求方法**：使用标准的HTTP方法（GET, POST, PUT, DELETE）。
- **请求参数**：使用查询参数或路径参数，避免使用请求体传递参数。
- **响应格式**：统一使用JSON格式，包含`code`、`message`和`data`字段。

  ```json
  {
      "code": 200,
      "message": "Success",
      "data": {
          "key": "value"
      }
  }
  ```

- **错误处理**：返回标准的错误响应格式，包含错误码和错误信息。

  ```json
  {
      "code": 400,
      "message": "Bad Request"
  }
  ```

## 6. 运维监控
```mermaid
graph LR
    Prometheus -->|采集| App
    Grafana -->|可视化| Prometheus
    App -->|日志| ELK
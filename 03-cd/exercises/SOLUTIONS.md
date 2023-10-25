# Bootcamp Devops Continuo - Módulo 4 - CI/CD

## Soluciones a ejercicios Jenkins

*NOTA: los comandos y rutas relativas toman como referencia el directorio actual (03-cd/exercises)*

### Ejercicio 1. CI/CD de una Java + Gradle

Se ha utilizado jenkins dockerizado a partir del Dockerfile propuesto, construyendo una imagen y ejecutando un contenedor a patir de ella:

```bash
docker build -t jenkinsgradle -f jenkins-resources/gradle.Dockerfile .
docker run -v jenkinsgradle_home:/var/jenkins_home -p 8080:8080 -p 50000:50000 jenkinsgradle
```

Se ha creado un repositorio público de GitHub con el código de la aplicación de ejemplo para descargarlo desde el pipeline: https://github.com/gamarr0/lemoncode-calculator

Creamos un job de tipo Pipeline en el que para el paso de obtener el código de un repositorio remoto utilizamos el step checkout que nos proporciona el plugin de git (que viene incluido en los plugins por defecto) y para los pasos de compilación y tests unitarios ejecutamos los comandos utilizando setps sh:

```groovy
pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        checkout scmGit(
          branches: [[name: 'master']],
          userRemoteConfigs: [[url: 'https://github.com/gamarr0/lemoncode-calculator.git']]
        )
      }
    }

    stage('Compile') {
      steps {
        sh './gradlew compileJava'
      }
    }

    stage('Unit tests') {
      steps {
        sh './gradlew test'
      }
    }
  }
}
```
*(solutions/jenkins-01/Jenkinsfile)*

![Ejecución del ejercicio 1 de Jenkins](solutions-images/jenkins-01.png)

### Ejercicio 2. Modificar la pipeline para que utilice la imagen Docker de Gradle como build runner

El entorno donde se ejecutará el pipeline consistirá en dos contenedores orquestados a través de docker compose, uno para el propio Jenkins y otro para el agente docker donde se levantarán los contenedores que ejecutaran las pipelines que lo requieran.

Empezamos creando un Dockerfile para el contenedor principal de Jenkins, ya que necesitamos extender la imagen de jenkins para instalar el cliente de docker y los plugins necesarios.

```Dockerfile
FROM jenkins/jenkins:lts

USER root
# install docker-cli
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli

USER jenkins
# install required plugins
RUN jenkins-plugin-cli --plugins docker-plugin:1.5 docker-workflow:572.v950f58993843
```
*(solutions/jenkins-02/Dockerfile)*

Para el agente utilizaremos la imagen oficial de Docker in Docker, por lo que pasamos directamente a definir el entorno utilizando docker compose.

```yaml
services:
  docker:
    image: docker:dind
    container_name: jenkins-docker
    privileged: true
    restart: unless-stopped
    environment:
      DOCKER_TLS_CERTDIR: /certs
    volumes:
      - docker_certs:/certs/client
      - jenkins_home:/var/jenkins_home

  jenkins:
    build: .
    container_name: jenkins
    restart: unless-stopped
    environment:
      DOCKER_HOST: tcp://docker:2376
      DOCKER_CERT_PATH: /certs/client
      DOCKER_TLS_VERIFY: 1
    volumes:
      - docker_certs:/certs/client:ro
      - jenkins_home:/var/jenkins_home
    ports:
      - 8080:8080
      - 50000:50000

volumes:
  docker_certs:
  jenkins_home:
```
*(solutions/jenkins-02/docker-compose.yml)*

Para levantar el entorno utilizamos docker compose, que directamente construira y descargará las imágenes necesarias para crear los contenedores.

```bash
docker compose -f solutions/jenkins-02/docker-compose.yml up
```

En cuanto al pipeline, es igual al del ejercicio anterior pero modificando el agente en el que queremos que se ejecute, indicando que sea `docker` y que utilice la imagen que indica el enunciado (`gradle:6.6.1-jre14-openj9`).

```groovy
pipeline {
  agent {
    docker {
      image 'gradle:6.6.1-jre14-openj9'
    }
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scmGit(
          branches: [[name: 'master']],
          userRemoteConfigs: [[url: 'https://github.com/gamarr0/lemoncode-calculator.git']]
        )
      }
    }

    stage('Compile') {
      steps {
        sh './gradlew compileJava'
      }
    }

    stage('Unit tests') {
      steps {
        sh './gradlew test'
      }
    }
  }
}
```
*(solutions/jenkins-02/Jenkinsfile)*

![Ejecución del ejercicio 2 de Jenkins](solutions-images/jenkins-02.png)

## Soluciones a ejercicios GitLab

### Ejercicio 1. CI/CD de una aplicación spring

Teniendo generado y configurado el par de claves ssh para el usuario de nuestro gitlab local, creamos el proyecto springapp, lo clonamos y añadimos los ficheros de la aplicación.

```bash
git clone ssh://git@gitlab.local:2222/developer1/springapp.git
cp -r ../bootcamprepo/03-cd/02-gitlab/springapp/* springapp/
git add .
git commit -m "Add app files"
git push
```

Utilizamos la rama por defecto main a la que añadimos el fichero *.gitlab-ci.yml* con el pipeline:

```yaml
.maven_jobs:
  image: maven:3.6.3-jdk-8-openj9

.docker_jobs:
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_JOB_TOKEN $CI_REGISTRY/$CI_PROJECT_PATH

workflow:
  rules:
    - if: '$CI_COMMIT_REF_NAME == "main"'
    - when: never

stages:
  - maven:build
  - maven:test
  - docker:build
  - deploy

build_app:
  stage: maven:build
  script:
    - mvn clean package
  artifacts:
    when: on_success
    paths:
      - "target/*.jar"
  needs: []
  extends: .maven_jobs

test_app:
  stage: maven:test
  script:
    - mvn verify
  artifacts:
    when: on_success
    reports:
      junit:
        - target/surefire-reports/TEST-*.xml
  needs: []
  extends: .maven_jobs

build_image:
  stage: docker:build
  script:
    - docker build -t $CI_REGISTRY/$CI_PROJECT_PATH:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY/$CI_PROJECT_PATH:$CI_COMMIT_SHA
  needs:
    - job: build_app
      artifacts: true
    - job: test_app
      artifacts: false
  extends: .docker_jobs

deploy:
  stage: deploy
  before_script:
    - !reference [.docker_jobs,before_script]
    - if [[ $(docker ps --filter "name=springapp" --format '{{.Names}}') == "springapp" ]]; then docker rm -f springapp; fi;
  script:
    - docker run --name "springapp" -d -p 8080:8080 $CI_REGISTRY/$CI_PROJECT_PATH:$CI_COMMIT_SHA
  needs:
    - job: build_image

```
*(solutions/gitlab-01/.gitlab-ci.yml)*

Detalles sobre el pipeline:
- Declaramos dos templates para reutilizar elementos comunes entre jobs, uno para los que usan maven y otro para los relacionados con docker. Los aprovechamos usando **extends** excepto para el job de deploy, que como tiene un comando adicional en **before_script** hay que utilizar **!reference** porque con **extends** se sobrescribe el **before_script** del template en vez de mezclarse.
- Usamos **workflow** para que el pipeline solo se ejecute en la rama main, ya que sería la única que nos interesa desplegar.
- Con **needs** afinamos el pipeline para que las dos primeras stages se puedan ejecutar en paralelo ya que son independientes, además de hacer que la construcción de la imagen de docker dependa de las dos primeras y la del deploy de la de la imagen, ya que no podemos desplegar sin la imagen y no queremos construir esta si no se ha compilado la aplicación o si los tests han fallado.
- Como usando **needs** por defecto un job obtiene los artefactos de los jobs que depende, indicamos cuando no necesitamos los artefactos para que sea más óptimo (por ejemplo el job que construye la imagen no necesita los resultados de los tests).

Tras hacer commit del fichero se ejecuta el pipeline:

![Ejecución del pipeline del ejercicio 1 de GitLab](solutions-images/gitlab-01-1.png)

Y podemos acceder a la aplicación a través de la URL indicada en el enunciado:

![Aplicación en ejecución del ejercicio 1 de GitLab](solutions-images/gitlab-01-2.png)

### Ejercicio 2. Crear un usuario nuevo y probar que no puede acceder al proyecto anteriormente creado



### Ejercicio 3. Crear un nuevo repositorio, que contenga una pipeline, que clone otro proyecto, springapp anteriormente creado.



## Soluciones a ejercicios GitHub Actions

### Ejercicio 1. Crea un workflow CI para el proyecto de frontend



### Ejercicio 2. Crea un workflow CD para el proyecto de frontend



### Ejercicio 3. Crea un workflow que ejecute tests e2e



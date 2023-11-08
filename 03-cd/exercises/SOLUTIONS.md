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

Si el pipeline lo guardásemos en el mismo repositorio que la aplicación el primer paso sería automático ya que se haría el checkout del repositorio al obtener el pipeline, pero como una de las stages propuestas en el enunciado de forma explícita es hacer el checkout del código desde un repositorio remoto podemos tenerlo en otro repositorio distinto o declararlo directamente en Jenkins.

Creamos un job de tipo Pipeline en el que para el paso de obtener el código de un repositorio remoto utilizamos el step **checkout** que nos proporciona el plugin de git (que viene incluido en los plugins por defecto) y para los pasos de compilación y tests unitarios ejecutamos los comandos utilizando setps **sh**:

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

Utilizamos la **rama** por defecto main a la que añadimos el fichero *.gitlab-ci.yml* con el pipeline:

```yaml
.maven_jobs:
  image: maven:3.6.3-jdk-8-openj9

.docker_jobs:
  image: docker:latest
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
  image: !reference [.docker_jobs,image]
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

Creamos un nuevo usuario y al loguearnos con él no aparece ningún repositorio, simplemente la página de bienvenida donde se le permite crear nuevos proyectos y grupos o explorar los repositorios públicos, que en este caso no hay ninguno.

Desde el usuario donde tenemos el proyecto del ejercicio anterior, añadimos al nuevo usuario como miembro al proyecto desde la sección **Project members** *(Project Information > Members)* del menú del proyecto pulsando el botón **Invite members**, donde especificaremos el usuario y su rol. Para ir comprobando los permisos para cada rol iremos cambiando su rol desde este mismo panel.

Tras probar a hacer las acciones propuestas con los distintos roles obtenemos los resultados resumidos en la siguiente tabla:

| Acción                   | Guest | Reporter | Developer | Maintainer |
|:-------------------------|:-----:|:--------:|:---------:|:----------:|
| Commit                   |       |    ~     |     X     |     X      |
| Pull                     |       |    X     |     X     |     X      |
| Push                     |       |          |     X     |     X      |
| Push (protected)         |       |          |           |     X      |
| Merge request            |       |    X     |     X     |     X      |
| Run pipeline             |       |          |     X     |     X      |
| Run pipeline (protected) |       |          |           |     X      |
| Administration           |       |          |           |     X      |

Algunas notas sobre los resultados:
- La acción *Commit* no se restringe directamente ya que se puede hacer commit en el repositorio de forma local, lo que realmente importa son los permisos que se tengan para hacer *Pull* de los commits existentes o hacer *Push* de nuevos commits.
- Derivado del punto anterior, para el rol *Reporter* se ha marcado la acción *Commit* con **~** queriendo indicar que puede ver los commits existentes (ya que puede hacer *Pull*) pero no puede añadir nuevos commits (ya que no puede hacer *Push*). Para hacer cambios lo único que puede hacer es crear un fork del repositorio con los cambios que quiere aplicar y crear un merge request que solicite mezclar los cambios de su fork al repositorio principal. Este merge request solo podrá mezclarlo un usuario con permisos sobre la rama destino.
- Las acciones de *Push* y *Run pipeline* se han separado en dos para diferenciar entre ramas no protegidas (normalmente las que se crean para añadir cambios que sean aplicados a través de merge requests) y protegidas (por defecto *main*).
- Aunque los permisos indicados sobre las ramas protegidas son los que hay por defecto, para cada rama protegida se puede permitir que los usuarios con rol *Developer* también puedan mezclar merge requests sobre ellas o hacer push directamente. Esto se hace desde la administración del proyecto, en la sección *Settings > Repository > Protected branches*.

### Ejercicio 3. Crear un nuevo repositorio, que contenga una pipeline, que clone otro proyecto, springapp anteriormente creado.

#### Método CI job permissions model

Creamos un repositorio desde otro usuario y definimos un pipeline sencillo que clone el proyecto y liste los ficheros, para lo que utilizamos una imagen de docker con git, por ejemplo **bitnami/git**.

```yaml
stages:
  - clone

clone_ci_job:
  stage: clone
  image: bitnami/git:latest
  script:
    - git clone http://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.local:8888/developer1/springapp.git
    - ls -R
```
*(solutions/gitlab-03-1/.gitlab-ci.yml)*

Probamos a ejecutar el pipeline en distintos escenarios en función de los permisos del nuevo usuario sobre el proyecto del repositorio que queremos clonar, obteniendo los siguientes resultados:

- Si el usuario no es miembro del proyecto a clonar el pipeline falla obteniendo el error `remote: The project you were looking for could not be found or you don't have permission to view it.`
- Si el usuario es miembro del proyecto a clonar pero su rol es *guest* el pipeline también falla, esta vez con el error `remote: You are not allowed to download code from this project.`
- Si el usuario es miembro del proyecto con un rol distinto a *guest*, el repositorio se clona correctamente y se listan sus ficheros en el output del pipeline

#### Método deploy keys

Generamos un par de claves privada/pública y añadimos la clave pública como *Deploy key* en el proyecto *springapp*, que es el que queremos clonar.

Cambiamos al usuario donde tenemos el nuevo proyecto que clonará el anterior y añadimos la clave privada como variable enmascarada en la configuración del proyecto (*Settings > CI/CD > Variables*), para lo que tendremos que codificarla utilizando *base64* para que no contenga caracteres no permitidos como saltos de línea. Haciéndola enmascarada evitaremos que la clave pueda aparecer en los logs.

El **script** de este pipeline es similar al anterior pero utilizamos SSH en vez de HTTP para clonar el repositorio, sin necesidad de indicar ninguna credencial en el comando, al igual que podríamos utilizar cualquier comando de git directamente. Para ello preparamos el contenedor donde se ejecuta el job realizando varias acciones en el **before_script**:
- Creamos el directorio **.ssh** para el usuario si no existiese y restringimos sus permisos al propio usuario.
- Decodificamos con *base64* la clave privada que tenemos en la variable enmascarada, la guardamos en el directorio **.ssh** y le restringimos los permisos al propio usuario, de modo que al estar en este directorio no haga falta añadirla al agente para que ssh la utilice.
- Añadimos los fingerprints del servidor de git a los hosts conocidos de ssh para que no nos solicite la aprobación al ejecutar comandos ssh y la conexión sea segura (evitando ataques Man in the middle).

```yaml
stages:
  - clone

clone_deploy_key:
  stage: clone
  image: bitnami/git:latest
  before_script:
    - mkdir -p ~/.ssh && chmod 700 ~/.ssh
    - echo "$EJ3_PRIVATE_KEY" | base64 -d > ~/.ssh/id_ed25519 && chmod 400 ~/.ssh/id_ed25519
    - ssh-keyscan gitlab.local >> ~/.ssh/known_hosts && chmod 644 ~/.ssh/known_hosts
  script:
    - git clone git@gitlab.local:developer1/springapp.git
    - ls -R
```
*(solutions/gitlab-03-2/.gitlab-ci.yml)*

Con este método el repositorio se clona correctamente independientemente de los permisos que tenga el usuario desde el que se ejecuta el pipeline sobre el proyecto, incluso sin ser miembro del mismo, ya que estamos utilizando la clave privada correspondiente a la pública que se ha añadido como *Deploy key* en el proyecto.

## Soluciones a ejercicios GitHub Actions

### Ejercicio 1. Crea un workflow CI para el proyecto de frontend

Copiamos en un nuevo repositorio público de GitHub el directorio indicado: https://github.com/gamarr0/lemoncode-hangman

Creamos la jerarquía de carpetas *.github/workflows/* en la raíz del repositorio y añadimos el workflow propuesto para CI:

```yaml
name: CI

on: pull_request

jobs:
  build:
    name: Build app
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 16
          cache: npm
          cache-dependency-path: hangman-front/package-lock.json
      - name: Build app
        working-directory: ./hangman-front
        run: |
          npm ci
          npm run build
  unit_tests:
    name: Unit tests
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 16
      - name: Execute unit tests
        working-directory: ./hangman-front
        run: |
          npm ci
          npm run test
```
*(solutions/github-01/ci.yml)*

Se cachean los paquetes de npm usando la configuración de la acción *actions/setup-node*.

Tras crear una pull request para probar comprobamos que el workflow se ejecuta correctamente:

![Workflow ejecutado en pull request](solutions-images/github-01.png)

### Ejercicio 2. Crea un workflow CD para el proyecto de frontend

Añadimos un fichero a *.github/workflows/* con el nuevo workflow para CD:

```yaml
name: CD

on: workflow_dispatch

jobs:
  deploy:
    name: Publish docker image
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: actions/checkout@v3
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build image
        working-directory: ./hangman-front
        run: |
          docker build -t ghcr.io/gamarr0/hangman-front:${{ github.sha }} .
      - name: Push image to registry
        run: |
          docker push ghcr.io/gamarr0/hangman-front:${{ github.sha }}
```
*(solutions/github-02/cd.yml)*

Utilizamos la acción *docker/login-action* para hacer login en el container registry de GitHub, configurando las credenciales a partir del contexto **github** (del que obtenermos el nombre de usuario) y de los secretos (de donde obtenemos el token de GitHub correspondiente al la ejecución del workflow actual que se crea por defecto).

Tras ejecutar el workflow de forma manual comprobamos que se ejecuta correctamente y que genera el paquete correspondiente a la imagen generada:

![Paquete generado en el repositorio de GitHub](solutions-images/github-02.png)

### Ejercicio 3. Crea un workflow que ejecute tests e2e

Añadimos a nuestro repositorio el directorio *hangman-e2e/e2e* que contiene la configuración y los tests de Cypress.

Creamos un nuevo workflow para los tests E2E que en principio se ejecutará de forma manual e independiente de los ejercicios anteriores:

```yaml
name: E2E

on: workflow_dispatch

jobs:
  e2e:
    name: E2E tests for hangman app
    runs-on: ubuntu-latest
    services:
      api:
        image: jaimesalas/hangman-api
        ports:
          - 3001:3000
      front:
        image: jaimesalas/hangman-front
        env:
          API_URL: http://localhost:3001
        ports:
          - 8080:8080
    steps:
      - uses: actions/checkout@v3
      - name: Execute tests
        uses: cypress-io/github-action@v6
        with:
          working-directory: hangman-e2e/e2e
```
*(solutions/github-03-1/e2e.yml)*

Para desplegar localmente la api y la aplicación front del proyecto utilizamos los **containerized services**, que nos permiten ejecutar contenedores de docker con la imagen y la configuración que se le especifique. 

Usamos la acción *cypress-io/github-action* para ejecutar Cypress, estableciendo en las opciones el directorio de trabajo donde tenemos la configuración.

Tras ejecutarlo comprobamos que se ejecuta correctamente:

![Alt text](solutions-images/github-03-1.png)

Para integrarlo con el ejercicio anterior, una alternativa a ejecutarlo de forma manual sería que se ejecute cuando el workflow CD termine correctamente, de modo que se ejecuten las pruebas sobre la nueva imagen publicada. Para ello se puede usar el evento **workflow_run** y obtener el hash de la imagen publicada usando el contexto **github**. Modificamos el workflow, quedando:

```yaml
name: E2E

on:
  workflow_run:
    workflows: [CD]
    types:
      - completed

jobs:
  e2e:
    name: E2E tests for hangman app
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    services:
      api:
        image: jaimesalas/hangman-api
        ports:
          - 3001:3000
      front:
        image: ghcr.io/gamarr0/hangman-front:${{ github.sha }}
        env:
          API_URL: http://localhost:3001
        ports:
          - 8080:8080
    steps:
      - uses: actions/checkout@v3
      - name: Execute tests
        uses: cypress-io/github-action@v6
        with:
          working-directory: hangman-e2e/e2e
```
*(solutions/github-03-2/e2e.yml)*

Establecemos un condicional al job usando **if** para que no se ejecute si el workflow para CD no se ha ejecutado correctamente. Como el workflow se ejecuta sobre el mismo commit del repositorio donde se ejecutó el workflow de CD, usando **github.sha** obtenemos el tag de la imagen que se acaba de generar.

Tras ejecutar el workflow de CD de nuevo comprobamos que cuando termina se lanza automáticamente una ejecución del workflow E2E:

![Alt text](solutions-images/github-03-2.png)

# Bootcamp Devops Continuo - Módulo 2 - Contenedores

## Soluciones a ejercicios

*NOTA: los comandos y rutas relativas toman como referencia el directorio actual (exercises)*

### 1. Dockerizar la aplicación dentro de lemoncode-challenge

Lo primero que necesitamos tener son las imágenes que utilizaremos para crear los distintos contenedores necesarios para desplegar la aplicación.

Para la base de datos utilizaremos directamente la imagen de mongo ya existente en dockerhub haciendo que los datos sean persistentes a través de un volumen. Para las otras dos partes de la aplicación, el backend y el frontend, crearemos imágenes con el código final y las herramientas necesarias para ejecutarlo de modo que se pueda versionar y distribuir fácilmente.

#### Backend

Para construir la imagen correspondiente al backend partiremos de las imágenes del sdk (para compilar la aplicación) y del runtime (para ejecutar la aplicación) de .NET del repositorio de microsoft, además del código fuente de nuestra aplicación.

Añadimos un fichero de definición *(Dockerfile)* al directorio de la aplicación, a través del cuál se construirá la imagen teniendo en cuenta:

* Copiamos los ficheros que indican las dependencias de la aplicación y las instalamos antes de nada, así aunque cambie el código fuente tendremos esta parte de la imagen cacheada si no han cambiado las dependencias (lo cual es menos común)
* Copiamos el código de la aplicación y lo compilamos
* Usando multistage build, partimos de la imagen del runtime de .NET y copiamos el resultado de la compilación anterior, de modo que nuestra imagen final solo tendrá el código compilado (ya que el código fuente no es necesario para la ejecución) y será mucho más ligera
* Exponemos el puerto 5000 y establecemos como punto de entrada el comando que ejecuta la apicación y como argumento por defecto un parámetro para que la aplicación escuche en la dirección que nos piden (pudiendo cambiar esta URL especificando el argumento al ejecutar el contenedor)


```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:3.1 as build-env
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /publish

FROM mcr.microsoft.com/dotnet/aspnet:3.1 as runtime
WORKDIR /publish
COPY --from=build-env /publish .

EXPOSE 5000

ENTRYPOINT ["dotnet", "backend.dll"]
CMD ["--urls", "http://topics-api:5000"]
```
*(lemoncode-challenge/dotnet-stack/backend/Dockerfile)*

Aunque en el código proporcionado teníamos la aplicación compilada, para partir de un contexto de compilación limpio y evitar incompatibilidades la compilamos al crear la imagen, por lo que podemos ignorar los directorios que no contienen código fuente. Para ello añadimos al contexto de la imagen un fichero `.dockerignore` con el siguiente contenido:

```
**/bin/
**/obj/
```
*(lemoncode-challenge/dotnet-stack/backend/.dockerignore)*

Para que la aplicación funcione correctamente en nuestro despliegue de contenedores solo hay que modificar la cadena de conexión de mongo en el fichero `appsettings.json` para que la cadena de conexión a base de datos sea `mongodb://some-mongo:27017`.

Ya solo falta construir la imagen de la aplicación con el siguiente comando (como no se indica ninguno concreto, le ponemos el tag latest por simplicidad):

`docker build -t lemoncode-challenge/backend:latest lemoncode-challenge/dotnet-stack/backend`

#### Frontend

Para el frontend, como utilizamos node que es un lenguaje interpretado, no necesitamos hacer multistage build para compilar pero si que reutilizaremos la técnica de copiar e instalar las dependencias antes que el código fuente para aprovechar la caché todo lo posible al construir la imagen para nuevas versiones de la aplicación.

El fichero de definición de la imagen, que añadimos al directorio de la aplicación, quedaría:

```dockerfile
FROM node:18-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY ["package.json", "package-lock.json*", "./"]
RUN npm install --production
COPY . .

EXPOSE 3000

CMD [ "node", "server.js" ]
```
*(lemoncode-challenge/node-stack/frontend/Dockerfile)*

En el código de la aplicación no necesitamos hacer ningún cambio ya que la URL de la API se puede especificar a través de la variable de entorno `API_URI` (como podemos ver en el fichero *server.js*).

Procedemos a construir la imagen con el siguiente comando:

`docker build -t lemoncode-challenge/frontend:latest lemoncode-challenge/node-stack/frontend`

#### Despliegue

Una vez tenemos las imágenes correspondientes a las distintas partes de la aplicación procedemos a desplegarla.

Creamos el volumen para persistir los datos de la base de datos y la red de tipo bridge que compartirán los contenedores de nuestra aplicación, aunque realmente no sería necesario ya que lo vamos a hacer con los valores por defecto y se crearían al crear los contenedores.

`docker volume create mongodb-data`

`docker network create lemoncode-challenge`

Iniciamos un contenedor para cada servicio de la aplicación, montando el volumen creado para los datos en el contenedor de mongo y especificando la misma red para todos. Como etiquetamos nuestras imágenes como latest, no es necesario especificar una versión concreta.

`docker run --name some-mongo -v mongodb-data:/data/db --network lemoncode-challenge -d mongo`

`docker run --name topics-api --network lemoncode-challenge -d lemoncode-challenge/backend`

`docker run --name topics-web --network lemoncode-challenge -p 8080:3000 -e API_URI=http://topics-api:5000/api/topics -d lemoncode-challenge/frontend`

Podemos añadir datos a la base de datos desde la propia consola a partir del fichero `Topics.json`. Para ello copiamos el fichero dentro del contenedor y lo importamos mediante la herramienta `mongoimport`, usando los siguientes comandos:

`docker cp Topics.json some-mongo:/tmp/Topics.json`

`docker exec some-mongo mongoimport --db TopicstoreDb --collection Topics --jsonArray /tmp/Topics.json`

### 2. Levantar el entorno para la aplicación lemoncode-challenge usando Docker Compose

En vez de tener que memorizar y ejecutar un comando para levantar cada contenedor de nuestra aplicación podemos desplegar la aplicación completa a través de Docker compose, que nos permitirá definir los distintos servicios y la configuración para cada uno en un único fichero.

Para reaprovechar los datos que tenemos en nuestro volumen creado en el ejercicio anterior en la definición del volumen indicamos que será un volumen externo, evitando que se cree uno nuevo para el contexto de este nuevo despliegue. También podríamos reutilizar la red de la misma forma pero como no lo necesitamos la mantenemos con la configuración por defecto, de modo que se creará una nueva red que tendrá el mismo ciclo de vida que el conjunto completo.

```yaml
version: "3"

services:
  some-mongo:
    image: mongo
    volumes:
      - mongodb-data:/data/db
    networks:
      - lemoncode-challenge
  topics-api:
    image: lemoncode-challenge/backend
    networks:
      - lemoncode-challenge
    depends_on:
      - some-mongo
  topics-web:
    image: lemoncode-challenge/frontend
    networks:
      - lemoncode-challenge
    ports:
      - "8080:3000"
    environment:
      - API_URI=http://topics-api:5000/api/topics
    depends_on:
      - topics-api

volumes:
  mongodb-data:
    external: true

networks:
  lemoncode-challenge:
```
*(lemoncode-challenge/docker-compose.yml)*

Para desplegar el entorno completo solo es necesario ejecutar un comando:

`docker compose -f lemoncode-challenge/docker-compose.yml up -d`

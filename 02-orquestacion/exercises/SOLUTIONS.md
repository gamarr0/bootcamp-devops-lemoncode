# Bootcamp Devops Continuo - Módulo 3 - Orquestación

## Soluciones a ejercicios

*NOTA: los comandos y rutas relativas toman como referencia el directorio actual (exercises)*

Para construir las imágenes necesarias en cada servicio y poder utilizarlas en minikube ha sido necesario construirlas usando el docker de minikube con la ayuda del comando `minikube docker-env`.

En todos los casos donde se utilizan imágenes locales ha sido necesario añadir `imagePullPolicy: Never` a la especificación del contenedor para que kubernetes no intente hacer el pull de la imagen.

Para poder utilizar los servicios de tipo LoadBalancer en minikube y que podamos acceder a ellos desde nuestro host se ha utilizado `minikube tunnel`.

### Ejercicio 1. Monolito en memoria

Definiciones:

* [Deployment](solutions/00-monolith-in-mem/00-depoyment.yaml)
* [Service](solutions/00-monolith-in-mem/01-service.yaml)

Comando para construir la imagen:

`docker build -t antonio/lc-todo-monolith-memory:v1 00-monolith-in-mem/todo-app`

Comando para desplegar la solución:

`kubectl create ns ejercicio1 && kubectl apply -n ejercicio1 -f solutions/00-monolith-in-mem`

### Ejercicio 2. Monolito

Definiciones:

* [StorageClass](solutions/01-monolith/00-storageClass.yaml)
* [PersistentVolume](solutions/01-monolith/01-persistentVolume.yaml)
* [Databse StatefulSet](solutions/01-monolith/02-statefulSet.yaml)
* [Database Service](solutions/01-monolith/03-db-service.yaml)
* [App ConfigMap](solutions/01-monolith/04-configMap.yaml)
* [App Deployment](solutions/01-monolith/05-deployment.yaml)
* [App Service](solutions/01-monolith/06-app-service.yaml)

Comandos para construir las imágenes:

`docker build -t antonio/lc-todo-db:v1 -f 01-monolith/todo-app{/Dockerfile.todos_db,}`

`docker build -t antonio/lc-todo-app:v1 01-monolith/todo-app`

Comando para desplegar la solución:

`kubectl create ns ejercicio2 && kubectl apply -n ejercicio2 -f solutions/01-monolith`

### Ejercicio 3. Aplicación Distribuida

Definiciones:

* [Api ConfigMap](solutions/02-distributed/00-api-configMap.yaml)
* [Api Deployment](solutions/02-distributed/01-api-deployment.yaml)
* [Api Service](solutions/02-distributed/02-api-service.yaml)
* [Front Deployment](solutions/02-distributed/03-front-deployment.yaml)
* [Front Service](solutions/02-distributed/04-front-service.yaml)
* [Ingress](solutions/02-distributed/05-ingress.yaml)

Comandos para construir las imágenes:

`docker build -t antonio/lc-todo-api:v1 02-distributed/todo-api`

`docker build -t antonio/lc-todo-front:v1 02-distributed/todo-front`

Comando para desplegar la solución:

`kubectl create ns ejercicio3 && kubectl apply -n ejercicio3 -f solutions/02-distributed`

# Bootcamp Devops Continuo - Módulo 3 - Orquestación

## Soluciones a ejercicios

*NOTA: los comandos y rutas relativas toman como referencia el directorio actual (exercises)*

Para construir las imágenes necesarias en cada servicio y poder utilizarlas en minikube ha sido necesario construirlas usando el docker de minikube con la ayuda del comando `minikube docker-env`.

En todos los casos donde se utilizan imágenes locales ha sido necesario añadir `imagePullPolicy: Never` a la especificación del contenedor para que kubernetes no intente hacer el pull de la imagen.

Para poder utilizar los servicios de tipo `LoadBalancer` y los `Ingress` en minikube y que podamos acceder a ellos desde nuestro host se ha utilizado el comando `minikube tunnel`.

### Ejercicio 1. Monolito en memoria

En este caso no nos conviene replicar los pods de la aplicación, ya que en cada visita un mismo usuario podría ver distintos datos, al estar guardados en memoria.

Definiciones:

* [Deployment](solutions/00-monolith-in-mem/00-depoyment.yaml)
  * La configuración se setea directamente como variables de entorno, se podría haber utilizado un `configMap` pero no se requería y las variables son muy estáticas
* [Service](solutions/00-monolith-in-mem/01-service.yaml)
  * Expone la aplicación en el puerto 3000 usando un balanceador del proveedor (en este caso minikube)

Comando para construir la imagen:

`docker build -t antonio/lc-todo-monolith-memory:v1 00-monolith-in-mem/todo-app`

Comando para desplegar la solución:

`kubectl create ns ejercicio1 && kubectl apply -n ejercicio1 -f solutions/00-monolith-in-mem`

### Ejercicio 2. Monolito

No ha sido necesario crear un `configMap` para la base de datos ya que se ha utilizado la configuración por defecto.

En vez de crear el `PersistentVolumeClaim` por separado y referenciarlo desde el `StatefulSet`, se ha optado por utilizar la propiedad `volumeClaimTemplates` del `StatefulSet` que creará un `PersistentVolumeClaim` automáticamente por cada réplica, ya que si tuviésemos varias réplicas de la base de datos no podrían compartir el mismo `PersistentVolume`.

Para que el usuario siempre vea los mismos datos solo podremos tener una sola réplica de la base de datos, ya que si tenemos más la aplicación podría conectarse a una distinta cada vez y se mostarían datos distintos (ya que las réplicas son independientes, no están clusterizadas).

Adicionalmente se ha añadido un `HorizontalPodAutoscaler` para los pods de la aplicación, de modo que se repliquen automáticamente cuando la carga aumente o disminuya.

Definiciones:

* [StorageClass](solutions/01-monolith/00-storageClass.yaml)
  * Se usa el provisioner local con la configuración por defecto
  * Se establece la opción `reclaimPolicy` a `Delete`, aunque solo la aplicará a los PersistentVolume creados dinámicamente, por lo que no nos afecta
* [PersistentVolume](solutions/01-monolith/01-persistentVolume.yaml)
  * Se establece `reclaimPolicy` a `Retain` para que no se elimine el volumen si se deja de utilizar, evitando pérdida de datos
  * Se utiliza el modo de acceso `ReadWriteOnce` para que el volumen persistente solo pueda ser utilizado por un nodo
* [PersistentVolumeClaim](solutions/01-monolith/02-persistentVolumeClaim.yaml)
  * Solicitamos un volumen persistente de 500 megas de la clase creada anteriormente
* [Databse StatefulSet](solutions/01-monolith/03-statefulSet.yaml)
  * Sólo una réplica para evitar tener los datos repartidos sin control
  * Se podría haber utilizado `volumeClaimTemplates` para que el `PersistentVolumeClaim` se genere automáticamente con cada réplica, pero no es necesario porque se ha decidido no replicar la base de datos y el enunciado pide que se cree explícitamente, además de que se tiene más control de que volumen se utiliza de esta forma
  * En cuanto a recursos solo se especifican límites, por lo que los recursos solicitados serán igual que estos y la penalización en caso de sobrecarga es menos probable para estos pod, lo cual resulta beneficioso ya que solo habrá una réplica de base de datos y es necesaria para el funcionamiento de la aplicación
* [Database Service](solutions/01-monolith/04-db-service.yaml)
  * Expone el puerto 5432 de los pod de la base de datos dentro del clúster
* [App ConfigMap](solutions/01-monolith/05-configMap.yaml)
  * Configuración del entorno de la aplicación y la conexión con la base de datos
* [App Deployment](solutions/01-monolith/06-deployment.yaml)
  * En principio 1 réplica, se escalarán automáticamente
  * Se añade un límite de recursos mayor que los solicitados para tener margen de tiempo mientras se generan nuevas réplicas en caso de un pico de carga, ya que el `HorizontalPodAutoscaler` utiliza los recursos solicitados para comprobar la utilización
  * Con la afinidad se intenta que las réplicas se desplieguen en los nodos donde esté la base de datos
* [App Service](solutions/01-monolith/07-app-service.yaml)
  * Se expone la aplicación en el puerto 3000 a través de un balanceador de carga del proveedor
* [App HorizontalPodAutoscaler](solutions/01-monolith/08-horizontalPodAutoscaler.yaml)
  * Se mantienen entre 2 y 10 réplicas en función de los recursos consumidos por la aplicación, intentando mantener la utilización de la cpu de cada pod al 50%

Comandos para construir las imágenes:

`docker build -t antonio/lc-todo-db:v1 -f 01-monolith/todo-app{/Dockerfile.todos_db,}`

`docker build -t antonio/lc-todo-app:v1 01-monolith/todo-app`

Comando para desplegar la solución:

`kubectl create ns ejercicio2 && kubectl apply -n ejercicio2 -f solutions/01-monolith`

### Ejercicio 3. Aplicación Distribuida

En este caso los datos se guardan en el pod de la api, por lo que si lo replicamos podríamos tener problemas con distintas visitas del mismo usuario en las que puede ver datos distintos. Para evitarlo se puede usar una `sticky session` para el enrutado de la api en el ingress (para el front no hace falta porque no cambia), aunque esta solución funciona solo temporalmente y de forma local al equipo, además de que también tendríamos el problema de que al escalar hacia abajo perderíamos los datos que hubiese en esos pods.

Adicionalmente se ha añadido un HorizontalPodAutoscaler para los pods del front, de modo que el número de pods se ajuste automáticamente a la carga.

Definiciones:

* [Api ConfigMap](solutions/02-distributed/00-api-configMap.yaml)
  * Configuración de entorno de la api
* [Api Deployment](solutions/02-distributed/01-api-deployment.yaml)
  * Solo 1 réplica para evitar problemas con los datos
* [Api Service](solutions/02-distributed/02-api-service.yaml)
  * Expone la api en el puerto 3000 dentro del clúster
* [Front Deployment](solutions/02-distributed/03-front-deployment.yaml)
  * En principio 1 réplica, se escalarán automáticamente
  * Se ha añadido una antiafinidad para que las réplicas que se vayan creando se intenten distribuir en nodos donde no se esté ejecutando ya alguna réplica del mismo pod a ser posible
* [Front Service](solutions/02-distributed/04-front-service.yaml)
  * Expone el front en el puerto 80 dentro del clúster
* [Ingress](solutions/02-distributed/05-ingress.yaml)
  * Expone los servicios de la api y el front como URLs del host `todo.lc`
  * Aunque se decide no escalar la API por los problemas mencionados anteriormente, le añadimos la sticky session a modo de 
* [Front HorizontalPodAutoscaler](solutions/02-distributed/06-horizontalPodAutoscaler.yaml)
  * Se mantienen entre 2 y 10 réplicas de nuevo usando la métrica de utilización de CPU, se podrían utilizar otras pero es necesario configurar el clúser para ello

Comandos para construir las imágenes:

`docker build -t antonio/lc-todo-api:v1 02-distributed/todo-api`

`docker build -t antonio/lc-todo-front:v1 02-distributed/todo-front`

Comando para desplegar la solución:

`kubectl create ns ejercicio3 && kubectl apply -n ejercicio3 -f solutions/02-distributed`

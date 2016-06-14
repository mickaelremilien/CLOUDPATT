# 5 Minutes Stacks, épisode XX : Wordpress HA  #

## Episode XX : Wordpress HA

![Wordpresslogo](http://images.google.fr/imgres?imgurl=https%3A%2F%2Fs3.amazonaws.com%2Feb-blog-blog%2Fwp-content%2Fuploads%2FWordpress-logo.png&imgrefurl=https%3A%2F%2Fwww.eventbrite.com%2Fblog%2Fds00-Wordpress-and-eventbrite-better-together%2F&h=400&w=680&tbnid=4xqaGdDVi68jeM%3A&docid=F_JiKOPa91dgVM&ei=ZtVfV8uFCsHWa7iIsuAO&tbm=isch&iact=rc&uact=3&dur=283&page=1&start=0&ndsp=20&ved=0ahUKEwjL0NjvoKfNAhVB6xoKHTiEDOwQMwhJKAswCw&bih=653&biw=1366)

Naissance du CMS dans sa version 0.7, c’est une évolution libre (open source) et gratuite du logiciel b2 créé par Michel Valdrighi en 2001, il est écrit en PHP et repose sur une base de données MySQL. C’est avant tout un moteur de blog.
Wordpress est donc un logiciel de la famille des systèmes de gestion de contenu ou encore CMS (Content Management System). Le CMS Wordpress permet à la fois de gagner du temps de développement au niveau de la création de votre site Internet et d’y ajouter facilement des pages, Wordpress permet donc de créer des sites dynamiques.
Wordpress premet au utilisateurs de gérer eux-mêmes leur site Web grâce à une console d’administration très claire, la profusion des menus et ses possibilités en matière de configuration peuvent rebuter les utilisateurs les plus néophytes.

## Descriptions

La stack "WordpressHA" permet de monter un architecture à Haute disponibilité applicative. Elle crée deux instances portant les serveurs applicatifs Apache loadbalancer en ROUND_ROBIN en utilisant la fonctionnalité LBAAS(Loadbalancer as a service) d'openstack ,ainsi qu'un cluster Mysql à replication en temps réelle, synchronisé grace la solution PerconaXtraDB et constitué de trois noeuds utilisant aussi la fonctionnalité LBAAS. Et enfin une instance servant de bastion pour se connecter aux différentes machines de la stack.

## Preparations

### Les versions
 - Wordpress 4.5.2
 - Percona-xtraDB
 - Apache
 - Php5

### Les pré-requis pour déployer cette stack
Ceci devrait être une routine à présent:

* Un accès internet
* Un shell linux
* Un [compte Cloudwatt](https://www.cloudwatt.com/cockpit/#/create-contact) avec une [ paire de clés existante](https://console.cloudwatt.com/project/access_and_security/?tab=access_security_tabs__keypairs_tab)
* Les outils [OpenStack CLI](http://docs.openstack.org/cli-reference/content/install_clients.html)
* Un clone local du dépôt git [Cloudwatt applications](https://github.com/cloudwatt/applications)

### Taille de l'instance
Par défaut, le script propose un déploiement sur une instance de type "Standard" (n2.cw.standard-2). Il
existe une variété d'autres types d'instances pour la satisfaction de vos multiples besoins. Les instances sont facturées à la minute, vous permettant de payer uniquement pour les services que vous avez consommés et plafonnées à leur prix mensuel (vous trouverez plus de détails sur la [Page tarifs](https://www.cloudwatt.com/fr/produits/tarifs.html) du site de Cloudwatt).

Vous pouvez ajuster les paramètres de la stack à votre goût.

## Tour du propriétaire

Une fois le dépôt cloné, vous trouverez le répertoire `bundle-coreos-cassandra/`

* `bundle-trusty-vpn.heat.yml`: Template d'orchestration HEAT, qui servira à déployer l'infrastructure nécessaire.
* `stack-start.sh`: Scipt de lancement de la stack, qui simplifie la saisie des paramètres et sécurise la création du mot de passe admin.

## Démarrage

### Initialiser l'environnement

Munissez-vous de vos identifiants Cloudwatt, et cliquez [ICI](https://console.cloudwatt.com/project/access_and_security/api_access/openrc/).
Si vous n'êtes pas connecté, vous passerez par l'écran d'authentification, puis le téléchargement d'un script démarrera. C'est grâce à celui-ci que vous pourrez initialiser les accès shell aux API Cloudwatt.

Sourcez le fichier téléchargé dans votre shell et entrez votre mot de passe lorsque vous êtes invité à utiliser les clients OpenStack.

~~~ bash
$ source COMPUTE-[...]-openrc.sh
Please enter your OpenStack Password:

~~~

Une fois ceci fait, les outils en ligne de commande d'OpenStack peuvent interagir avec votre compte Cloudwatt.


### Ajuster les paramètres

Dans le fichier `bundle-trusty-vpn.heat.yml` vous trouverez en haut une section `parameters`. Le seul paramètre obligatoire à ajuster
est celui nommé `keypair_name` dont la valeur `default` doit contenir le nom d'une paire de clés valide dans votre compte utilisateur.
C'est dans ce même fichier que vous pouvez ajuster la taille de l'instance par le paramètre `flavor_name`.

Vous devrez saisir en entrée de la stack le mot de passe de la base de donnée mysql `themysqlpwd` qui permettra la connexion à distance sur le cluster Mysql. Ce mot de passe devra faire entre 6 et 24 caractères.

~~~ yaml

heat_template_version: 2013-05-23

parameters:
  image:
    type: string
    description: Glance Image
    default: "Ubuntu 14.04"

  flavor:
    type: string
    description: Flavor
    default: n2.cw.standard-2

  keypair_name:
    type: string
    description: SSH key
    default: mickael

  public_net_id:
    type: string
    description: Public network ID
    default: 6ea98324-0f14-49f6-97c0-885d1b8dc517

  themysqlpwd:
    description: Basic auth password for mysql users
    label: Mysql Auth password
    type: string
    hidden: true
    constraints:
      - length: { min: 6, max: 24 }
        description: Password must be between 6 and 24 characters

[...]
~~~

Par défaut, les ports utilisés par Wordpress, Mysql et Percona-xtraDB ne sont accessibles que sur le réseau local, si vous souhaitez changer ces règles de filtrage (pour ouvrir par exemple le port 3306), vous pouvez également éditer le fichier `bundle-trusty-Wordpressfr1.heat.yml`.

~~~ yaml
security_group:
  type: OS::Neutron::SecurityGroup
  properties:
    rules:
      - { direction: ingress, protocol: TCP, port_range_min: 22, port_range_max: 22 }
      - { direction: ingress, protocol: TCP, port_range_min: 80, port_range_max: 80 }
      - { direction: ingress, protocol: TCP, port_range_min: 443, port_range_max: 443 }
      - { direction: ingress, protocol: ICMP }
      - { direction: egress, protocol: TCP, port_range_min: 80, port_range_max: 80 }
      - { direction: egress, protocol: ICMP }
      - { direction: egress, protocol: TCP }
      - { direction: egress, protocol: UDP }
~~~


### Démarrer la stack

Dans un shell, lancer le script `stack-start.sh`:

~~~
./stack-start.sh nom\_de\_votre\_stack
~~~

Exemple :

~~~bash
$ ./stack-start.sh Wordpress
+--------------------------------------+-----------------+--------------------+----------------------+
| id                                   | stack_name      | stack_status       | creation_time        |
+--------------------------------------+-----------------+--------------------+----------------------+
| ee873a3a-a306-4127-8647-4bc80469cec4 |    Wordpress    | CREATE_IN_PROGRESS | 2015-11-25T11:03:51Z |
+--------------------------------------+-----------------+--------------------+----------------------+
~~~

Puis attendez **5 minutes** que le déploiement soit complet.


 ~~~ bash
 $ watch -n 1 heat stack-list
 +--------------------------------------+------------+-----------------+----------------------+
 | id                                   | stack_name | stack_status    | creation_time        |
 +--------------------------------------+------------+-----------------+----------------------+
 | xixixx-xixxi-ixixi-xiixxxi-ixxxixixi | Wordpress  | CREATE_COMPLETE | 2025-10-23T07:27:69Z |
 +--------------------------------------+------------+-----------------+----------------------+
 ~~~
 ### C’est bien tout ça, mais vous n’auriez pas un moyen de lancer l’application par la console ?

 Et bien si ! En utilisant la console, vous pouvez déployer un serveur Vpn :

 1. Allez sur le Github Cloudwatt dans le répertoire applications/bundle-trusty-mean
 2. Cliquez sur le fichier nommé bundle-trusty-vpn.heat.yml
 3. Cliquez sur RAW, une page web apparait avec le détail du script
 4. Enregistrez-sous le contenu sur votre PC dans un fichier avec le nom proposé par votre navigateur (enlever le .txt à la fin)
 5. Rendez-vous à la section « Stacks » de la console.
 6. Cliquez sur « Lancer la stack », puis cliquez sur « le fichier du modèle » et sélectionnez le fichier que vous venez de sauvegarder sur votre PC, puis cliquez sur « SUIVANT »
 7. Donnez un nom à votre stack dans le champ « Nom de la stack »
 8. Entrez votre keypair dans le champ « keypair_name »
 9. Entrez votre mot de passe Mysql dans le champ « themysqlpwd »


Le script `start-stack.sh` s'occupe de lancer les appels nécessaires sur les API Cloudwatt pour :

* démarrer 5 instances basées sur Ubnuntu, pré-provisionnée avec la stack WordpressHA.
* configurer deux noeuds Wordpress webserveur et un cluster de base de données Percona-xtraDB comprenant 3 neouds Mysqlserver.

![WordpressHA-Archi](http://www.samn0.fr/wp-content/uploads/2011/03/800px-VPN_site-to-site.jpg)

### Enjoy

Une fois tout ceci fait vous avez une application Wordpress prêtte à être utilisée, vous pouvez récupérer les IP (publics et privées), l'url de votre site, les sous réseaux,les réseaux, associées aux instances créées grâce à la commande suivante (la section `outputs` liste les outputs de la stack) :

Vous pouvez visualiser les parametres de sortie de la stack dans la console
en cliquant sur : Stack → le nom de votre stack → l'onglet vue d'ensemble

Les outputs de la stack sont :
- wp_floating_url ( l'url de votre site web )
- sql_vip( l'ip privée des instances web )
- web_vip ( l'ip privée des instances web )
- sql_scale_up ( web scale policy )
- sql_scale_down ( web scale policy )
- web_scale_up ( web scale policy )
- web_scale_down ( web scale policy )
- server_id ( l'id de l'instance serveur Wordpress et Mysql )
- first_address ( l'ip public du bastion)

~~~ bash
$ heat stack-show Wordpress
+-----------------------+---------------------------------------------------+
| Property              | Value                                             |
+-----------------------+---------------------------------------------------+
|                     [...]                                                 |
| outputs               | [                                                 |
|                       |   {                                               |
|                       |     "output_value": "10.0.1.100",                 |
|                       |     "description": "server3 private IP address",  |
|                       |     "output_key": "server3_private_ip"            |
|                       |   },                                              |
|                       |   {                                               |
|                       |     "output_value": "10.0.1.102",                 |
|                       |     "description": "server1 private IP address",  |
|                       |     "output_key": "server1_private_ip"            |
|                       |   },                                              |
|                       |   {                                               |
|                       |     "output_value": "XX.XX.XX.XX",                |
|                       |     "description": "server3 public IP address",   |
|                       |     "output_key": "server3_public_ip"             |
|                       |   },                                              |
|                       |   {                                               |
|                       |     "output_value": "YY.YY.YY.YY",                |
|                       |     "description": "server1 public IP address",   |
|                       |     "output_key": "server1_public_ip"             |
|                       |   },                                              |
|                       |   {                                               |
|                       |     "output_value": "10.0.1.103",                 |
|                       |     "description": "server2 private IP address",  |
|                       |     "output_key": "server2_private_ip"            |
|                       |   },                                              |
|                       |   {                                               |
|                       |     "output_value": "ZZ.ZZ.ZZ.ZZ",                |
|                       |     "description": "server2 public IP address",   |
|                       |     "output_key": "server2_public_ip"             |
|                       |   }                                               |
|                       | ]                                                 |
|                     [...]                                                 |
+-----------------------+---------------------------------------------------+
~~~


### Administer le serveur  Wordpress

~~~ bash
ssh -i <keypair> cloud@<node-ip@>

~~~

### Consulter les logs de Wordpress

Les logs de services Wordpress sont visibles via ligne de commande

~~~ bash
ssh -i <keypair> core@<node-ip@>

~~~

Wordpress sauvegarde ses logs dans les fichiers `/var/log/syslog` et `/var/log/apache2/error.log`
Mysql sauvegarde ses logs dans les fichiers `/var/log/syslog` et `/var/log/mysql/error.log`

~~~ bash
ssh -i <keypair> cloud@<node-ip@>
tail -n 100 /var/log/Wordpress.log
grep VPN /var/log/syslog
~~~

### Les fichiers importants sont :

#### pour les Webserver:

- `/var/www/wordpress/wp-config.php`: fichiers de configuration de la connexion distante au  Cluster Mysql
- `/etc/apache2/sites-available/000-default.conf`: fichiers de configuration du Virtualhost Wordpress

#### pour les Mysqlserver:

- `/etc/mysql/conf.d/galera.cnf`: fichier de configuration de Galera
- `/etc/mysql/my.cnf`: fichier de configuration de Mysql

#### Autres sources pouvant vous intéresser:

* [Wordpress Homepage](https://fr.wordpress.org/)
* [PerconaHomepage](https://www.percona.com/)

-----
Have fun. Hack in peace.

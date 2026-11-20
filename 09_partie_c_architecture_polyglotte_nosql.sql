-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE C : TRANSACTIONS ACID, AUDIT ET CHOIX NOSQL
-- POINT 9 : Architecture Polyglotte pour Application de Covoiturage (3 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

/*
===============================================================================
ÉNONCÉ DU BESOIN DE LA STARTUP DE COVOITURAGE TEMPS RÉEL :
===============================================================================
Une startup lance une application de covoiturage soumise à 3 charges distinctes :
  (a) Suivi GPS en temps réel de 30 000 véhicules toutes les 3 secondes
      (= 10 000 écritures par seconde continues, séries temporelles massives).
  (b) Facturation bancaire des trajets, gestion des soldes et des paiements
      (zéro tolérance aux erreurs financières ou pertes de transactions).
  (c) Moteur social de suggestion de trajets via amis et amis d'amis communs
      (requêtes de graphe relationnel à 3 degrés de séparation).

En architecture d'entreprise moderne, aucun moteur unique ne peut exceller sur 
ces trois profils antagonistes. La solution optimale est une ARCHITECTURE POLYGLOTTE.


===============================================================================
1. DÉCOMPOSITION DE L'ARCHITECTURE POLYGLOTTE PROPOSÉE
===============================================================================

+---------------------------------------------------------------------------------------+
| COMPOSANT (a) : SUIVI GPS TEMPS RÉEL & SÉRIES TEMPORELLES                             |
+---------------------------------------------------------------------------------------+
* Moteur recommandé : APACHE CASSANDRA (ou ScyllaDB) / Alternative : REDIS TIME-SERIES
* Profil CAP / PACELC : 
  - Système AP (Théorème CAP de Brewer) : Disponibilité (A) + Tolérance au partitionnement (P).
  - Profil PACELC : PA / EL (Si partition : Availability ; Sinon : Latency minimale).
* Justification via les 4 critères de choix :
  1. Cohérence requise : Cohérence éventuelle (Eventual Consistency). Si une coordonnée GPS 
     arrive avec 500 ms de décalage ou qu'un nœud est indisponible, l'application ne doit 
     JAMAIS bloquer la réception des pings des autres véhicules.
  2. Scalabilité & Volumétrie : Scalabilité horizontale massive sans SPOF (Single Point of 
     Failure). 10 000 pings/sec génèrent ~864 millions de points GPS par jour. Le modèle 
     d'écriture append-only en LSM-Tree de Cassandra encaisse ce débit sans ralentissement.
  3. Structure des données : Colonnes Larges (Wide-Column). Modèle optimisé par clé de 
     partitionnement et clé de clustering :
     PRIMARY KEY ((vehicle_id, date_jour), recorded_at) WITH CLUSTERING ORDER BY (recorded_at DESC).
  4. Nature des accès : Écritures massives en continu et lecture par clé directe O(1) de la 
     dernière position connue.


+---------------------------------------------------------------------------------------+
| COMPOSANT (b) : FACTURATION BANCAIRE, PORTAL ET TRANSACTIONS FINANCIÈRES             |
+---------------------------------------------------------------------------------------+
* Moteur recommandé : POSTGRESQL (ou MySQL 8 InnoDB)
* Profil CAP / PACELC : 
  - Système CP (Théorème CAP) : Cohérence forte (C) + Tolérance au partitionnement (P).
  - Profil PACELC : PC / EC (Si partition : Consistency ; Sinon : Consistency).
* Justification via les 4 critères de choix :
  1. Cohérence requise : Zéro tolérance à l'incohérence financière. Les transactions doivent 
     respecter impérativement les 4 propriétés ACID. Impossible de débiter un passager sans 
     créditer le chauffeur.
  2. Scalabilité : Montée en charge verticale avec réplicas en lecture seule (Read Replicas). 
     Le volume des courses terminées et des factures est stable et modéré par rapport au flux GPS.
  3. Structure des données : Données hautement relationnelles, normalisées en 3FN, avec contraintes 
     d'intégrité référentielle strictes (Foreign Keys, contraintes CHECK de solde positif).
  4. Nature des accès : Transactions complexes multi-tables (UPDATE + INSERT factures) et 
     requêtes analytiques de reporting comptable / TVA.


+---------------------------------------------------------------------------------------+
| COMPOSANT (c) : MOTEUR DE RECOMMANDATION D'ITINÉRAIRES & AMIS COMMUNS                 |
+---------------------------------------------------------------------------------------+
* Moteur recommandé : NEO4J (Base orientée Graphe)
* Profil CAP / PACELC :
  - Profil PACELC : PC / EC (par défaut pour les clusters Neo4j Causal Clustering).
* Justification via les 4 critères de choix :
  1. Cohérence requise : Cohérence forte sur les liens du réseau social des utilisateurs.
  2. Scalabilité : Scalabilité orientée complexité des relations plutôt que gigantisme brut.
  3. Structure des données : Réseau maillé non-tabulaire. Modèle en Nœuds (:User, :Trajet, :Ville) 
     et Relations orientées dotées de propriétés ([:AMI_AVEC], [:A_VOYAGE_AVEC {note: 5}]).
  4. Nature des accès : Traversées multi-sauts (Graph Traversal).
     En SQL classique, chercher des amis à 3 degrés de séparation impose 3 auto-jointures 
     (JOIN... JOIN... JOIN) avec une complexité exponentielle en O(N^3) qui fait s'effondrer 
     le processeur.
     Dans Neo4j, grâce à l'Index-Free Adjacency (chaque nœud pointe directement en mémoire sur 
     ses voisins sans passer par un index central), le coût d'exploration est proportionnel 
     uniquement au sous-graphe visité O(k^3), s'exécutant en 5 millisecondes en langage CYPHER.


+---------------------------------------------------------------------------------------+
| COMPOSANT BONUS TRANSVERSE : CACHE & GÉOLOCALISATION ULTRA-RAPIDE                     |
+---------------------------------------------------------------------------------------+
* Moteur : REDIS (In-Memory Key-Value & Geospatial)
  - Utilisé pour stocker les sessions actives des passagers et les positions instantanées 
    avec GEOADD / GEORADIUS afin de trouver les conducteurs à moins de 2 km en 0.2 ms.


===============================================================================
2. SYNTHÈSE DE LA GRILLE DE DÉCISION (RÉSUMÉ POUR LA NOTATION)
===============================================================================

| Fonctionnalité métier      | Technologie choisie | Famille NoSQL / SQL | Profil PACELC | Raison technique déterminante                       |
|----------------------------|---------------------|---------------------|---------------|-----------------------------------------------------|
| (a) Télémétrie 30k GPS/3s  | Cassandra / Scylla  | Colonnes Larges     | PA / EL       | Écritures massives append-only sans verrou (LSM)    |
| (b) Facturation & Virements| PostgreSQL / InnoDB | SGBD Relationnel    | PC / EC       | Transactions ACID, zéro incohérence monétaire      |
| (c) Amis à 3 degrés / Trajets| Neo4j             | Graphe              | PC / EC       | Index-Free Adjacency : parcours multi-sauts en ms   |
| (Cache) Géofencing temps réel| Redis              | Clé-Valeur en RAM   | PA / EL       | Vitesse mémoire pure O(1) avec expiration TTL       |
*/

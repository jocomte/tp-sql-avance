À Corriger
# TP Évalué - SQL Avancé & Bases NoSQL (DataLab B2)

* **Étudiant** : Johan COLAS
* **Module** : SQL Avancé, Optimisation & NoSQL (DataLab B2)
* **Date de rendu** : Vendredi 20 Novembre 2026 - 16h00
* **Environnement cible** : MySQL 8.0+ / InnoDB & PostgreSQL (Compatibilité double SGBD)

---

## 📁 Inventaire des Livrables

Ce dépôt regroupe les scripts `.sql` correspondant point par point aux exigences du sujet d'évaluation (Barème total : 20 points) :

### 🟢 Partie A — Audit, Optimisation et Indexation SQL (7 points)
* [`01_partie_a_audit_explain.sql`](./01_partie_a_audit_explain.sql) (2 pts) : 
  * Exécution sous `EXPLAIN ANALYZE` de la requête initiale non-optimisée (`YEAR(date_commande) = 2026`).
  * Identification et analyse détaillée des **2 défauts majeurs** du plan d'exécution (Prédicat non-SARGable forçant un Seq/Table Scan en $\mathcal{O}(N)$ et tri bloquant `Using filesort` / `Sort` alourdi par `SELECT *`).
* [`02_partie_a_index_partitionnement_sargable.sql`](./02_partie_a_index_partitionnement_sargable.sql) (2.5 pts) :
  * Réécriture de la requête 100 % SARGable avec bornes d'intervalles et projection stricte des colonnes.
  * Création de l'index composite pertinent `idx_commandes_statut_date_montant` (respectant la règle du préfixe gauche).
  * Implémentation du partitionnement `RANGE` sur `date_commande` (avec la règle d'or de la clé primaire composite).
  * Mesure du gain de coût total avant/après et explication du phénomène de **Partition Pruning** (élagage des tiroirs de données).
* [`03_partie_a_vue_materialisee.sql`](./03_partie_a_vue_materialisee.sql) (2.5 pts) :
  * Création de la vue matérialisée `mv_synthese_segments` (chiffre d'affaires et volume par segment client).
  * Insertion d'une commande test et démonstration de l'obsolescence des données (**stale data** / photo figée).
  * Procédure de rafraîchissement (`REFRESH`) et contrôle de la mise à jour des totaux.

---

### 🟡 Partie B — Normalisation et Requêtes Analytiques Avancées (6 points)
* [`04_partie_b_normalisation_3fn.sql`](./04_partie_b_normalisation_3fn.sql) (2 pts) :
  * Décomposition rigoureuse en 3FN de la table brute `affectations_brutes`.
  * Identification formalisée des Dépendances Fonctionnelles (DF).
  * Élimination des listes concaténées (1FN), des dépendances partielles sur clé composite (2FN) et des dépendances transitives (3FN).
  * Script DDL complet avec clés primaires et contraintes de clés étrangères (`departements`, `employes_normalises`, `chefs_projet`, `projets`, `affectations_projets`).
* [`05_partie_b_cte_dense_rank.sql`](./05_partie_b_cte_dense_rank.sql) (2 pts) :
  * Requête analytique combinant une CTE (`WITH`) et la fonction de fenêtrage `DENSE_RANK() OVER (PARTITION BY ... ORDER BY ...)` pour extraire le Top 2 des produits les plus chers par catégorie.
  * Justification comparative de l'usage de `DENSE_RANK()` face à `RANK()` et `ROW_NUMBER()` pour le traitement équitable des ex-aequo.
* [`06_partie_b_with_recursive_organigramme.sql`](./06_partie_b_with_recursive_organigramme.sql) (2 pts) :
  * Requête récursive (`WITH RECURSIVE`) descendant l'arbre hiérarchique de l'entreprise depuis la CTO (`manager_id IS NULL`).
  * Calcul du niveau hiérarchique (`niveau`) et construction dynamique du fil d'Ariane (`chemin`).
  * Implémentation d'un garde-fou (`WHERE o.niveau < 10`) pour sécuriser le serveur contre tout cycle infini.

---

### 🔴 Partie C — Transactions ACID, Audit et Choix NoSQL (7 points)
* [`07_partie_c_not_in_null_not_exists.sql`](./07_partie_c_not_in_null_not_exists.sql) (2 pts) :
  * Analyse du piège de la requête `id NOT IN (SELECT manager_id ...)` qui renvoie 0 ligne.
  * Démonstration mathématique de la logique ternaire SQL (*Three-Valued Logic* : `TRUE`, `FALSE`, `UNKNOWN`) provoquée par la valeur `NULL` de la direction.
  * Solutions de correction robustes via `NOT EXISTS` (recommandée), `LEFT JOIN / IS NULL` et `NOT IN` filtré.
* [`08_partie_c_acid_isolation_wal.sql`](./08_partie_c_acid_isolation_wal.sql) (2 pts) :
  * Reproduction pas à pas du phénomène de **Non-Repeatable Read** sous le niveau d'isolation `READ COMMITTED`.
  * Résolution sous `REPEATABLE READ` grâce au mécanisme de snapshot MVCC.
  * Explication approfondie du rôle du journal d'intention **WAL** (*Write-Ahead Log* / Redo Log) lors d'un crash serveur en plein virement bancaire (garantie d'Atomicité par Rollback Undo et de Durabilité par Redo).
* [`09_partie_c_architecture_polyglotte_nosql.sql`](./09_partie_c_architecture_polyglotte_nosql.sql) (3 pts) :
  * Proposition d'architecture polyglotte pour une startup de covoiturage temps réel :
    * **(a) Suivi GPS (30 000 véhicules toutes les 3s)** : Apache Cassandra (Colonnes Larges, profil PACELC **PA / EL**, écriture append-only LSM-Tree).
    * **(b) Facturation bancaire des trajets** : PostgreSQL / InnoDB (SGBD Relationnel ACID, profil PACELC **PC / EC**, zéro tolérance à l'incohérence financière).
    * **(c) Moteur social d'amis à 3 degrés de séparation** : Neo4j (Base orientée Graphe, profil PACELC **PC / EC**, traversée de graphe en quelques millisecondes via l'*Index-Free Adjacency* évitant les jointures $\mathcal{O}(N^3)$).
    * **Composant Cache transverse** : Redis (Clé-Valeur en RAM pour sessions et géolocalisation ultra-rapide).

---

## 🚀 Guide de Déploiement et d'Exécution

### 1. Initialisation Git et Push vers GitHub / GitLab
Pour lier ce dossier local à votre dépôt distant :

```bash
# Dans le dossier tp_sql_avance :
git init
git add .
git commit -m "feat: rendu final complet TP SQL Avancé - DataLab B2"

# Lier à votre dépôt GitHub ou GitLab public :
git remote add origin https://github.com/<votre-compte>/tp-sql-avance.git
git branch -M main
git push -u origin main
```

### 2. Exécution des scripts dans votre console SQL
Les scripts peuvent être exécutés directement via phpMyAdmin, MySQL Workbench, DBeaver ou en ligne de commande :

```bash
mysql -u root -p advanced_sql < 01_partie_a_audit_explain.sql
mysql -u root -p advanced_sql < 02_partie_a_index_partitionnement_sargable.sql
mysql -u root -p advanced_sql < 03_partie_a_vue_materialisee.sql
mysql -u root -p advanced_sql < 04_partie_b_normalisation_3fn.sql
mysql -u root -p advanced_sql < 05_partie_b_cte_dense_rank.sql
mysql -u root -p advanced_sql < 06_partie_b_with_recursive_organigramme.sql
mysql -u root -p advanced_sql < 07_partie_c_not_in_null_not_exists.sql
mysql -u root -p advanced_sql < 08_partie_c_acid_isolation_wal.sql
```

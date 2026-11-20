-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE A : AUDIT, OPTIMISATION ET INDEXATION SQL
-- POINT 1 : Diagnostic et audit de requête avec EXPLAIN ANALYZE (2 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Requête initiale non-optimisée soumise à l'audit :
-- "Lister les 10 plus grosses commandes LIVREE passées en 2026 en utilisant
--  YEAR(date_commande) = 2026"
-- ----------------------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM commandes
WHERE YEAR(date_commande) = 2026
  AND statut = 'LIVREE'
ORDER BY montant_total DESC
LIMIT 10;

-- ============================================================================
-- 2. IDENTIFICATION DES 2 DÉFAUTS MAJEURS DU PLAN D'EXÉCUTION
-- ============================================================================

/*
DÉFAUT N°1 : PRÉDICAT NON-SARGABLE SUR LA COLONNE DE DATE (YEAR(date_commande) = 2026)
--------------------------------------------------------------------------------------
* Explication technique :
  Le prédicat YEAR(date_commande) = 2026 enveloppe la colonne date_commande dans une 
  fonction scalaire. En SQL, cela casse la "SARGabilité" (Search ARGument-able) du filtre.
  Même si un index B-Tree existe sur la colonne date_commande, le moteur ne peut pas
  l'utiliser pour une descente d'arbre (Index Scan / Index Range Scan), car l'arbre B-Tree 
  est ordonné selon les valeurs brutes de dates ('2026-01-14 10:00:00'), et non selon 
  le résultat de la fonction YEAR().

* Conséquence dans le plan d'exécution :
  L'optimiseur est contraint d'abandonner l'accès indexé et de basculer vers un 
  balayage séquentiel complet de la table :
  - PostgreSQL : Seq Scan sur commandes (en O(N))
  - MySQL / MariaDB : type = ALL (Full Table Scan)
  Le moteur doit charger chaque bloc de la table en mémoire et exécuter la fonction 
  YEAR() sur chaque ligne une par une, provoquant une consommation CPU et des lectures
  disque (I/O) excessives.


DÉFAUT N°2 : TRI BLOQUANT EN MÉMOIRE / DISQUE (Sort / filesort) COUPLÉ AU SELECT *
----------------------------------------------------------------------------------
* Explication technique :
  La clause ORDER BY montant_total DESC oblige le moteur à classer l'ensemble des 
  lignes satisfaisant le filtre avant de pouvoir isoler les 10 premières (LIMIT 10).
  Comme aucun index composite n'ordonne au préalable les données par montant_total,
  le moteur doit matérialiser un opérateur de tri bloquant :
  - PostgreSQL : Sort Method: top-N heapsort (ou external merge sort sur disque si work_mem est dépassé)
  - MySQL / MariaDB : Extra = Using filesort

* Aggravation par le SELECT * :
  L'utilisation de SELECT * force le moteur à copier la totalité des colonnes de chaque 
  ligne retenue dans l'espace mémoire de tri (sort_buffer_size sous MySQL / work_mem sous PostgreSQL).
  Cela alourdit l'empreinte mémoire, augmente les risques de débordement sur disque temporaire,
  et empêche tout Index Only Scan (Using index).
*/

-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE A : AUDIT, OPTIMISATION ET INDEXATION SQL
-- POINT 3 : Vue Matérialisée, Détection de Stale Data et Refresh (2.5 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CRÉATION DE LA VUE MATÉRIALISÉE
-- ----------------------------------------------------------------------------
-- Une vue matérialisée calcule le résultat d'une requête agrégée lourde 
-- et le stocke physiquement sur disque (comme une table dédiée) pour garantir
-- un affichage quasi-instantané (0.1 ms) sans refaire de jointures ni de SUM().

-- >>> Syntaxe Standard PostgreSQL (conforme au cours) :
-- CREATE MATERIALIZED VIEW mv_synthese_segments AS
-- SELECT 
--     c.segment,
--     COUNT(cmd.id) AS nb_commandes,
--     ROUND(SUM(cmd.montant_total), 2) AS ca_total
-- FROM clients c
-- JOIN commandes cmd ON cmd.client_id = c.id
-- WHERE cmd.statut = 'LIVREE'
-- GROUP BY c.segment;

-- >>> Équivalent complet sous MySQL 8 / InnoDB :
-- Comme MySQL ne dispose pas du mot-clé natif "MATERIALIZED VIEW", le patron de 
-- conception standard consiste à matérialiser la table de synthèse via CREATE TABLE ... AS SELECT :

DROP TABLE IF EXISTS mv_synthese_segments;
CREATE TABLE mv_synthese_segments AS
SELECT 
    c.segment,
    COUNT(cmd.id) AS nb_commandes,
    ROUND(SUM(cmd.montant_total), 2) AS ca_total
FROM clients c
JOIN commandes cmd ON cmd.client_id = c.id
WHERE cmd.statut = 'LIVREE'
GROUP BY c.segment;

-- Indexation de la vue matérialisée pour accélérer les requêtes du dashboard :
ALTER TABLE mv_synthese_segments ADD PRIMARY KEY (segment);

-- Lecture initiale de la vue matérialisée :
SELECT * FROM mv_synthese_segments ORDER BY ca_total DESC;


-- ----------------------------------------------------------------------------
-- 2. INSERTION D'UNE NOUVELLE COMMANDE TEST
-- ----------------------------------------------------------------------------
-- On insère une nouvelle commande volumineuse (ex: 50 000.00 €) pour le client n°1 (Camille Laurent, segment 'Entreprise') :

INSERT INTO commandes (client_id, date_commande, montant_total, statut)
VALUES (1, '2026-11-20 10:30:00', 50000.00, 'LIVREE');


-- ----------------------------------------------------------------------------
-- 3. CONSTAT DU CARACTÈRE OBSOLÈTE (STALE DATA) DE LA VUE
-- ----------------------------------------------------------------------------
-- Interrogeons de nouveau la vue matérialisée immédiatement après l'insertion :
SELECT * FROM mv_synthese_segments WHERE segment = 'Entreprise';

/*
CONSTAT ET EXPLICATION DU COMPORTEMENT :
----------------------------------------
* Résultat observé :
  Le montant ca_total et le nb_commandes pour le segment 'Entreprise' n'ont PAS bougé !
  La nouvelle commande de 50 000.00 € n'apparaît pas dans la vue.

* Pourquoi la vue est-elle "stale" (obsolète) ?
  Contrairement à une vue classique (CREATE VIEW) qui est un simple alias réexécutant 
  la requête sous-jacente en temps réel, une vue matérialisée est une "PHOTO IMPRIMÉE" 
  stockée sur disque.
  Le moteur n'effectue aucune synchronisation automatique lors des INSERT / UPDATE 
  sur les tables sources, afin de ne pas ralentir les écritures en production (OLTP).
  Les données de la vue sont donc désynchronisées (stale) jusqu'au prochain rafraîchissement.
*/


-- ----------------------------------------------------------------------------
-- 4. RAFRAÎCHISSEMENT DE LA VUE MATÉRIALISÉE ET VÉRIFICATION DE LA MISE À JOUR
-- ----------------------------------------------------------------------------

-- >>> Commande de rafraîchissement sous PostgreSQL :
-- REFRESH MATERIALIZED VIEW mv_synthese_segments;

-- >>> Procédure de rafraîchissement sous MySQL 8 :
TRUNCATE TABLE mv_synthese_segments;
INSERT INTO mv_synthese_segments (segment, nb_commandes, ca_total)
SELECT 
    c.segment,
    COUNT(cmd.id) AS nb_commandes,
    ROUND(SUM(cmd.montant_total), 2) AS ca_total
FROM clients c
JOIN commandes cmd ON cmd.client_id = c.id
WHERE cmd.statut = 'LIVREE'
GROUP BY c.segment;

-- Vérification finale de la mise à jour :
SELECT * FROM mv_synthese_segments WHERE segment = 'Entreprise';

/*
* Résultat après Refresh :
  Le chiffre d'affaires du segment 'Entreprise' inclut désormais les 50 000.00 € et 
  le compteur de commandes est incrémenté de 1. La vue est redevenue cohérente avec la réalité.
*/

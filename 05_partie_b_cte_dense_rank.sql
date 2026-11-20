-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE B : NORMALISATION ET REQUÊTES ANALYTIQUES AVANCÉES
-- POINT 5 : Requête avec CTE et Fonction de Fenêtrage DENSE_RANK (2 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. REQUÊTE ANALYTIQUE : TOP 2 DES PRODUITS LES PLUS CHERS PAR CATÉGORIE
-- ----------------------------------------------------------------------------

WITH classement_produits AS (
    SELECT 
        p.id AS produit_id,
        p.nom AS produit_nom,
        c.id AS categorie_id,
        c.nom AS categorie_nom,
        p.prix_unitaire,
        -- Fonction de fenêtrage partitionnée par catégorie et triée par prix décroissant
        DENSE_RANK() OVER (
            PARTITION BY p.categorie_id 
            ORDER BY p.prix_unitaire DESC
        ) AS rang_prix
    FROM produits p
    JOIN categories c ON c.id = p.categorie_id
)
SELECT 
    categorie_nom AS categorie,
    rang_prix,
    produit_nom AS produit,
    prix_unitaire
FROM classement_produits
WHERE rang_prix <= 2
ORDER BY categorie_id ASC, rang_prix ASC, prix_unitaire DESC;


-- ----------------------------------------------------------------------------
-- 2. VÉRIFICATION DU PLAN D'EXÉCUTION (EXPLAIN ANALYZE)
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
WITH classement_produits AS (
    SELECT 
        p.id AS produit_id,
        p.nom AS produit_nom,
        c.nom AS categorie_nom,
        p.prix_unitaire,
        DENSE_RANK() OVER (
            PARTITION BY p.categorie_id 
            ORDER BY p.prix_unitaire DESC
        ) AS rang_prix
    FROM produits p
    JOIN categories c ON c.id = p.categorie_id
)
SELECT * FROM classement_produits WHERE rang_prix <= 2;


-- ============================================================================
-- 3. JUSTIFICATION PÉDAGOGIQUE DU CHOIX DE DENSE_RANK()
-- ============================================================================
/*
POURQUOI UTILISER DENSE_RANK() PLUTÔT QUE ROW_NUMBER() OU RANK() ?
------------------------------------------------------------------
Imaginons 3 produits dans une même catégorie aux prix suivants :
Produit A : 2000 €
Produit B : 2000 € (ex-aequo)
Produit C : 1500 €

1. Avec ROW_NUMBER() :
   - Numérotation arbitraire : A reçoit 1, B reçoit 2, C reçoit 3.
   - Problème : Si le filtre demande `WHERE rang <= 2`, C est éliminé alors que 
     A et B avaient le même prix exact. C'est un départage injuste et non déterministe.

2. Avec RANK() :
   - Saut de rang après ex-aequo : A reçoit 1, B reçoit 1, et C reçoit 3 (le rang 2 est sauté).
   - Problème : Le filtre `WHERE rang <= 2` n'affichera que le rang 1 (A et B), 
     mais AUCUN produit classé 2ème ne figurera dans le rapport !

3. Avec DENSE_RANK() :
   - Rangs contigus sans trou : A reçoit 1, B reçoit 1, et C reçoit 2.
   - Résultat parfait : Les ex-aequo partagent la plus haute marche, et le produit 
     suivant est légitimement identifié comme le 2ème niveau de prix. 
   - Le filtre `WHERE rang_prix <= 2` capture rigoureusement les deux plus hauts 
     niveaux de prix du rayon.
*/

-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE C : TRANSACTIONS ACID, AUDIT ET CHOIX NOSQL
-- POINT 7 : Piège du NOT IN face à la logique ternaire des NULL (2 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. LA REQUÊTE PIÈGE (QUI RENVOIE INCORRECTEMENT 0 LIGNE)
-- ----------------------------------------------------------------------------
-- Objectif métier : "Lister les employés qui n'encadrent personne (non-managers)"

SELECT id, nom 
FROM employes 
WHERE id NOT IN (SELECT manager_id FROM employes);

-- Résultat dans la console : 0 ligne retournée !
-- Pourtant, la majorité des techniciens, analystes et développeurs n'ont aucune équipe.


-- ============================================================================
-- 2. DÉCRYPTAGE DU PIÈGE : LA LOGIQUE TERNAIRE DU SQL (Three-Valued Logic)
-- ============================================================================
/*
POURQUOI CETTE REQUÊTE ÉCHOUE-T-ELLE SYSTÉMATIQUEMENT ?
-------------------------------------------------------
1. La sous-requête `SELECT manager_id FROM employes` produit un ensemble de valeurs.
   Comme la CTO Claire Moreau n'a pas de supérieur hiérarchique, son `manager_id` vaut NULL.
   L'ensemble retourné contient donc : { 1, 2, 3, 4, 5, 7, NULL }.

2. L'opérateur SQL `x NOT IN (val1, val2, ..., valN)` est équivalent selon la norme ANSI 
   à une suite de conjonctions d'inégalités :
   (x != val1) AND (x != val2) AND ... AND (x != NULL)

3. En logique SQL ternaire (TRUE, FALSE, UNKNOWN) :
   Toute comparaison logique face à une valeur NULL (y compris `x = NULL` ou `x != NULL`) 
   ne s'évalue JAMAIS à TRUE ni à FALSE, mais s'évalue obligatoirement à UNKNOWN (Inconnu).

4. Conséquence mathématique dans la clause WHERE :
   Pour chaque employé (ex: Bastien Royer, id = 10) :
   (10 != 1) AND (10 != 2) ... AND (10 != NULL)
   => TRUE AND TRUE ... AND UNKNOWN
   => UNKNOWN !

   Une clause WHERE ne sélectionne une ligne QUE si l'expression booléenne globale 
   s'évalue à TRUE. Comme l'expression vaut UNKNOWN pour 100 % des lignes de la table, 
   le moteur rejette toutes les lignes et renvoie désespérément 0 résultat.
*/


-- ============================================================================
-- 3. PROPOSITIONS DE CORRECTIONS FIABLES ET OPTIMALES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CORRECTION N°1 : LA SOLUTION DE RÉFÉRENCE VIA NOT EXISTS (Recommandée)
-- ----------------------------------------------------------------------------
-- NOT EXISTS utilise une sémantique d'existence binaire (TRUE ou FALSE).
-- La présence d'une valeur NULL dans une colonne n'affecte jamais NOT EXISTS.
-- De plus, l'optimiseur SQL sait la transformer en Anti-Semi-Join très rapide.

SELECT e.id, e.nom, e.poste, e.departement
FROM employes e
WHERE NOT EXISTS (
    SELECT 1 
    FROM employes m 
    WHERE m.manager_id = e.id
);


-- ----------------------------------------------------------------------------
-- CORRECTION N°2 : VIA LEFT JOIN / IS NULL (Anti-Jointure)
-- ----------------------------------------------------------------------------
-- On fait une jointure externe vers les subordonnés, et on ne retient que 
-- les employés pour lesquels aucune correspondance n'a été trouvée (m.id IS NULL).

SELECT e.id, e.nom, e.poste, e.departement
FROM employes e
LEFT JOIN employes m ON m.manager_id = e.id
WHERE m.id IS NULL;


-- ----------------------------------------------------------------------------
-- CORRECTION N°3 : VIA NOT IN SÉCURISÉ (Filtrage explicite du NULL)
-- ----------------------------------------------------------------------------
-- Si l'on souhaite conserver la syntaxe NOT IN, il faut impérativement exclure 
-- les valeurs NULL de la sous-requête via `WHERE manager_id IS NOT NULL`.

SELECT id, nom, poste, departement
FROM employes
WHERE id NOT IN (
    SELECT manager_id 
    FROM employes 
    WHERE manager_id IS NOT NULL
);

-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE B : NORMALISATION ET REQUÊTES ANALYTIQUES AVANCÉES
-- POINT 6 : Organigramme d'Entreprise avec WITH RECURSIVE (2 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. REQUÊTE RÉCURSIVE D'ORGANIGRAMME COMPLET
-- ----------------------------------------------------------------------------
-- Structure en 3 volets :
--  1) Terme d'ancrage : Racine hiérarchique (Claire Moreau, CTO où manager_id IS NULL)
--  2) UNION ALL : Concaténation itérative des niveaux
--  3) Terme récursif : Descente d'un cran dans l'arbre à chaque passe avec garde-fou

WITH RECURSIVE organigramme AS (
    -- ------------------------------------------------------------------------
    -- 1. TERME D'ANCRAGE : La Directrice Technique (Niveau 1)
    -- ------------------------------------------------------------------------
    SELECT 
        id,
        nom,
        poste,
        departement,
        salaire,
        manager_id,
        1 AS niveau,
        -- Transtypage en chaîne longue pour éviter le débordement de taille en récursion
        CAST(nom AS CHAR(500)) AS chemin
    FROM employes
    WHERE manager_id IS NULL

    UNION ALL

    -- ------------------------------------------------------------------------
    -- 2. TERME RÉCURSIF : Les N+1 rattachés aux managers du tour précédent
    -- ------------------------------------------------------------------------
    SELECT 
        e.id,
        e.nom,
        e.poste,
        e.departement,
        e.salaire,
        e.manager_id,
        o.niveau + 1 AS niveau,
        CONCAT(o.chemin, ' > ', e.nom) AS chemin
    FROM employes e
    JOIN organigramme o ON e.manager_id = o.id
    WHERE o.niveau < 10 -- GARDE-FOU VITAL contre les boucles infinies cycliques
)
SELECT 
    id,
    nom,
    poste,
    departement,
    niveau,
    chemin,
    salaire
FROM organigramme
ORDER BY niveau ASC, departement ASC, id ASC;


-- ============================================================================
-- 2. EXPLICATION DES MÉCANISMES CLÉS DE LA REQUÊTE RÉCURSIVE
-- ============================================================================
/*
A) Le rôle du terme d'ancrage (Anchor member) :
   Il s'exécute une seule fois au démarrage. Il filtre la ligne de départ 
   (Claire Moreau, manager_id IS NULL) et initialise les colonnes calculées :
   niveau = 1 et chemin = 'Claire Moreau'.

B) Le fonctionnement de la boucle itérative (Recursive member) :
   À chaque tour T, le moteur prend les lignes produites au tour T-1 (la table 
   virtuelle 'organigramme') et les joint avec la table de base 'employes' 
   sur la condition `e.manager_id = o.id`.
   - Tour 1 : Trouve Marc Delacroix (Data) et Sophie Vasseur (Infra) -> niveau 2.
   - Tour 2 : Trouve Antoine Renaud, Nadia Benali, Julien Caron, Pauline Lefort, Romain Fabre -> niveau 3.
   - Tour 3 : Trouve Émilie Maillard, Bastien Royer, Kévin Giraud, Océane Simon -> niveau 4.
   - Tour 4 : Aucun employé n'a pour manager ces techniciens/DBA juniors -> L'ensemble est vide, l'algorithme s'arrête proprement.

C) La nécessité absolue du garde-fou (WHERE o.niveau < 10) :
   En entreprise, une erreur de saisie RH peut introduire une relation cyclique 
   (A est chef de B, et par erreur B est marqué chef de A). 
   Sans le filtre `WHERE o.niveau < 10`, le moteur tournerait en boucle infinie 
   jusqu'à l'épuisement de la mémoire RAM du serveur ou le dépassement de cte_max_recursion_depth.
*/

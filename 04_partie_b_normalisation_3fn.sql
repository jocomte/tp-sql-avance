-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE B : NORMALISATION ET REQUÊTES ANALYTIQUES AVANCÉES
-- POINT 4 : Normalisation en 3FN d'une table brute (2 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

/*
TABLE BRUTE SOUMISE À L'AUDIT :
--------------------------------
affectations_brutes (
    employe_id, 
    employe_nom, 
    dept_nom, 
    projets_liste,       -- Exemple: "DataPlatform (x1), MigrationCloud (x2)"
    chef_projet, 
    chef_projet_tel
)

===============================================================================
1. ANALYSE DES DÉPENDANCES FONCTIONNELLES (DF) & PROBLÈMES DÉTECTÉS
===============================================================================

DF 1 : employe_id -> employe_nom, dept_nom
       (Le nom de l'employé et son département dépendent uniquement de son identifiant employé)

DF 2 : projet_id -> projet_nom, chef_projet_id
       (Le nom du projet et le responsable dépendent du projet)

DF 3 : chef_projet_id -> chef_projet_nom, chef_projet_tel
       (Le numéro de téléphone du chef de projet dépend de la personne, pas du projet !)

DF 4 : (employe_id, projet_id) -> quantite_ou_heures
       (La participation d'un employé à un projet particulier dépend du couple)

Anomalies constatées sur la table brute :
- Violation 1FN : La colonne `projets_liste` contient des listes concaténées non atomiques.
- Violation 2FN : Des attributs (ex: employe_nom) ne dépendent que d'un morceau de la clé composite d'affectation.
- Violation 3FN : Présence d'une dépendance transitive non-clé :
  projet -> chef_projet -> chef_projet_tel (si le chef change de téléphone, risque d'incohérence sur 500 projets).


===============================================================================
2. PASSAGE PROGRESSIF EN FORMES NORMALES (1FN -> 2FN -> 3FN)
===============================================================================

ÉTAPE 1 : PREMIÈRE FORME NORMALE (1FN) - "Une seule information par case"
--------------------------------------------------------------------------
Condition : Attributs atomiques + Définition d'une clé primaire.
Action : Éclatement de `projets_liste` pour obtenir une ligne par projet associé à l'employé.
On introduit l'identifiant `projet_id`.
La clé candidate devient composite : (employe_id, projet_id).

ÉTAPE 2 : DEUXIÈME FORME NORMALE (2FN) - "Dépendance totale de la clé"
-----------------------------------------------------------------------
Condition : Être en 1FN + Tout attribut non-clé doit dépendre de la TOTALITÉ de la clé primaire.
Action :
- `employe_nom` et `dept_nom` ne dépendent que de `employe_id` (pas de projet_id) => Sortis vers la table `employes`.
- `chef_projet` et `chef_projet_tel` ne dépendent que de `projet_id` (pas de employe_id) => Sortis vers la table `projets`.
- La table de liaison `employe_projets` ne conserve que (employe_id, projet_id).

ÉTAPE 3 : TROISIÈME FORME NORMALE (3FN) - "Aucune dépendance transitive"
------------------------------------------------------------------------
Condition : Être en 2FN + Aucun attribut non-clé ne doit dépendre d'un autre attribut non-clé.
Action :
- Dans la table des projets : projet_id -> chef_projet -> chef_projet_tel.
  Le téléphone dépend du chef, pas du projet lui-même.
  => On extrait une table dédiée `chefs_projet(id, nom, telephone)`.
- Si le département possède d'autres attributs (ou pour éviter les redondances de libellés) :
  => On isole `departements(id, nom)`.
*/

-- ============================================================================
-- 3. SCRIPT DDL DU SCHÉMA RELATIONNEL FINAL EN 3FN
-- ============================================================================

-- 1. Table des Départements
CREATE TABLE IF NOT EXISTS departements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- 2. Table des Employés (Liée au département)
CREATE TABLE IF NOT EXISTS employes_normalises (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(150) NOT NULL,
    departement_id INT NOT NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (departement_id) REFERENCES departements(id)
) ENGINE=InnoDB;

-- 3. Table des Chefs de Projet (Élimination de la dépendance transitive 3FN)
CREATE TABLE IF NOT EXISTS chefs_projet (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(150) NOT NULL,
    telephone VARCHAR(30) NOT NULL
) ENGINE=InnoDB;

-- 4. Table des Projets (Liée au Chef de projet)
CREATE TABLE IF NOT EXISTS projets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code_projet VARCHAR(50) NOT NULL UNIQUE,
    nom VARCHAR(150) NOT NULL,
    chef_projet_id INT NOT NULL,
    CONSTRAINT fk_proj_chef FOREIGN KEY (chef_projet_id) REFERENCES chefs_projet(id)
) ENGINE=InnoDB;

-- 5. Table de Liaison des Affectations (Relation N-N en 1FN / 2FN / 3FN)
CREATE TABLE IF NOT EXISTS affectations_projets (
    employe_id INT NOT NULL,
    projet_id INT NOT NULL,
    date_affectation DATE NOT NULL DEFAULT (CURRENT_DATE),
    heures_allouees INT NOT NULL DEFAULT 35,
    PRIMARY KEY (employe_id, projet_id),
    CONSTRAINT fk_aff_employe FOREIGN KEY (employe_id) REFERENCES employes_normalises(id) ON DELETE CASCADE,
    CONSTRAINT fk_aff_projet FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE CASCADE
) ENGINE=InnoDB;

/*
Bilan 3FN :
- Clés primaires définies sur chaque table (atomicité garantie).
- Zéro dépendance partielle : les affectations relient uniquement les deux clés.
- Zéro dépendance transitive : les coordonnées du chef sont stockées à un seul endroit.
*/

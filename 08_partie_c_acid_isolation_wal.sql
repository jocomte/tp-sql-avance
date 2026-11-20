-- ============================================================================
-- TP SQL AVANCÉ - DATALAB B2
-- PARTIE C : TRANSACTIONS ACID, AUDIT ET CHOIX NOSQL
-- POINT 8 : Anomalie Non-Repeatable Read, Niveaux d'Isolation et Rôle du WAL (2 pts)
-- ============================================================================
-- Auteur : Johan COLAS
-- Date   : Novembre 2026
-- ============================================================================

-- ============================================================================
-- 1. REPRODUCTION D'UN NON-REPEATABLE READ SOUS READ COMMITTED
-- ============================================================================
/*
SCÉNARIO CHRONOLOGIQUE :
Deux sessions concurrentes interagissent avec la table `comptes_bancaires` :
Compte cible : id = 1 ('HexaTech SAS'), Solde initial = 15 000.00 €

| Temps | SESSION 1 (Lecteur / Contrôleur de gestion)   | SESSION 2 (Comptable / Modificateur)      |
|-------|-----------------------------------------------|-------------------------------------------|
| T1    | SET TRANSACTION ISOLATION LEVEL               |                                           |
|       | READ COMMITTED;                               |                                           |
|       | START TRANSACTION;                            |                                           |
| T2    | SELECT solde FROM comptes_bancaires           |                                           |
|       | WHERE id = 1;                                 |                                           |
|       | -> Lit : 15 000.00 €                          |                                           |
| T3    |                                               | START TRANSACTION;                        |
|       |                                               | UPDATE comptes_bancaires                  |
|       |                                               | SET solde = solde - 3000.00               |
|       |                                               | WHERE id = 1;                             |
|       |                                               | COMMIT; -- (Nouveau solde = 12 000.00 €)  |
| T4    | SELECT solde FROM comptes_bancaires           |                                           |
|       | WHERE id = 1;                                 |                                           |
|       | -> Lit : 12 000.00 € !                        |                                           |
|       | COMMIT;                                       |                                           |

ANOMALIE CONSTATÉE :
Au sein d'une seule et même transaction active (Session 1), la même requête 
exécutée deux fois renvoie deux résultats différents pour la même ligne. 
C'est la définition exacte du NON-REPEATABLE READ (Lecture non reproductible).
*/

-- Code SQL Session 1 (Sous READ COMMITTED) :
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT solde FROM comptes_bancaires WHERE id = 1; -- Retourne 15 000.00
-- [Attente du COMMIT de la Session 2...]
SELECT solde FROM comptes_bancaires WHERE id = 1; -- Retourne 12 000.00 (Anomalie !)
COMMIT;

-- Code SQL Session 2 (Modification externe) :
START TRANSACTION;
UPDATE comptes_bancaires SET solde = solde - 3000.00 WHERE id = 1;
COMMIT;


-- ============================================================================
-- 2. RÉSOLUTION DE L'ANOMALIE SOUS REPEATABLE READ
-- ============================================================================
/*
MÉCANISME MVCC (Multi-Version Concurrency Control) :
Sous le niveau REPEATABLE READ (niveau par défaut d'InnoDB sous MySQL) :
- Au premier SELECT, le moteur fige un "Snapshot" (instantané cohérent) de la base 
  fondé sur le numéro de transaction en cours.
- Même si la Session 2 modifie et valide la ligne avec un COMMIT entre temps, 
  la Session 1 continue de lire l'ancienne version de la ligne stockée dans les 
  segments d'annulation (Undo Logs / Undo Segments).
*/

-- Code SQL Session 1 (Sous REPEATABLE READ - Résolution) :
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT solde FROM comptes_bancaires WHERE id = 1; -- Lit 12 000.00
-- [Session 2 fait un nouvel UPDATE et un COMMIT...]
SELECT solde FROM comptes_bancaires WHERE id = 1; -- Relit STRICTEMENT 12 000.00 !
COMMIT;


-- ============================================================================
-- 3. LE RÔLE DU WAL (WRITE-AHEAD LOG) LORS D'UN CRASH EN PLEIN VIREMENT
-- ============================================================================
/*
SCÉNARIO D'INCIDENT CRITIQUE :
On effectue un virement de 5 000.00 € du compte 1 (HexaTech) vers le compte 2 (NovaLab) :
1. UPDATE comptes_bancaires SET solde = solde - 5000 WHERE id = 1; (Exécuté en mémoire)
2. >>> COUPURE DE COURANT / CRASH MATÉRIEL BRUTAL DU SERVEUR <<<
Le crédit du compte 2 n'a jamais pu être exécuté !

LE RÔLE VITAL DU WAL (Write-Ahead Logging / Redo Log InnoDB) :
-------------------------------------------------------------
* Règle fondamentale du WAL :
  "Aucun bloc de données (data page) n'est écrit de façon définitive sur le disque 
   avant que l'enregistrement d'intention correspondant n'ait été écrit et synchronisé 
   (fsync) dans le journal séquentiel du WAL".

* Procédure automatique de CRASH RECOVERY au redémarrage :
  Au redémarrage du serveur, le moteur (PostgreSQL ou InnoDB) inspecte automatiquement le WAL :

  1. Phase REDO (Rejouer le passé) :
     Le moteur rejoue toutes les opérations validées par un COMMIT mais qui se trouvaient 
     encore dans le cache RAM au moment de la coupure, garantissant la propriété de DURABILITÉ (D).

  2. Phase UNDO / ROLLBACK (Nettoyer les opérations orphelines) :
     Le moteur identifie la transaction de virement : l'instruction 1 a été amorcée, 
     mais AUCUN enregistrement de COMMIT n'est présent dans le journal.
     Le moteur lit les images avant modification (Undo Logs) et annule immédiatement 
     le débit du compte 1. Le solde d'HexaTech est restauré à sa valeur initiale.

* Conclusion :
  Grâce au WAL, le SGBD garantit l'ATOMICITÉ (A de ACID) : la transaction est traitée 
  comme une unité indivisible (Tout ou Rien). Pas un seul centime n'est perdu ni créé 
  artificiellement dans le système.
*/

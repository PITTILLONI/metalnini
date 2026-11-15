# Circle pit : se relever et rester dans le cercle

Date : 2026-11-15. Statut : validé par le propriétaire (« ok »). Petit changement, suite de la vue drone (branche `pit-moteur`).

## Pourquoi
En jouant au banc `?pitbanc`, le propriétaire trouve que c'est « très drôle mais la jouabilité est encore un peu compliquée » : **se relever** et **rester dans le cercle**.
- Se relever : il faut lâcher l'écran et taper 4 fois vite, alors que le pouce est posé pour courir ; rien ne montre que la relève avance.
- Rester dans le cercle : le côté du pouce donne une vitesse latérale, le moindre écart fait dériver vers le bord ou le milieu.

## Ce qui change
- **Voies au lieu de dérive** : le côté du pouce choisit une voie cible (piste au centre r = 0,7 ; bord r = 0,96 à droite ; milieu r = 0,3 à gauche), le coureur y va à la vitesse latérale actuelle et y reste ; pouce centré ou levé = retour sur la piste.
- **Marge au centre** : 25 px de chaque côté ne comptent pas (`inputFrom`).
- **Se relever avec le geste de course** : à terre, une poussée franche vers le haut (pouce passé sous 0,3 puis au-dessus de 0,6 pendant 0,15 s) relève ; les touchers marchent toujours ; la relève seule reste à 1,5 s. Une fois debout, on reprend à la moitié de la vitesse demandée par le pouce.
- **Repères** : anneau doré qui se remplit autour de son coureur à terre (`me.upProgress`, de 0 à 1) et message « Pousse vers le haut ! » ; au sol, piste légèrement éclairée, bord en or, milieu en rouge.

## Approches
| Approche | Décision |
|---|---|
| Voie cible + retour sur la piste (ci-dessus) | retenue |
| Garder la dérive, ajouter une marge | écartée : on dérive encore dès qu'on dépasse la marge |
| Commandes en deux boutons (bord / milieu) | écartée : casse le geste unique du pouce |

## Inchangé
Règles, score, fantômes, serveur, relever ses potes et attirer un pote (au bord, on y reste tant que le pouce est à droite).

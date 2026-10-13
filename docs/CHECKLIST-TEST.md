# Checklist de test manuel — Void Echo 0.1

À faire avec le build Release (`./scripts/install.sh`), sur un Mac Apple silicon. Prévoir un **second appareil** (téléphone, autre ordinateur) ou un **navigateur** pour rejoindre la réunion de l'autre côté.

**Sur meet.jit.si, une salle ne démarre qu'avec un modérateur connecté** (compte Google ou GitHub, bouton « Log-in » de Jitsi). Pour tester sans compte, régler d'abord le serveur sur un serveur Jitsi qui ne l'exige pas (par exemple `meet.ffmuc.net`, utilisé pendant le développement), puis refaire la section 1 sur meet.jit.si avec connexion (section 9).

## 0. Premier lancement

- [ ] L'app s'ouvre sur l'accueil : logo, « Void Echo », deux boutons, « Récentes » vide (« Les réunions que vous rejoignez apparaîtront ici. »), thème sombre, accent violet.
- [ ] Aucune demande d'autorisation au lancement.
- [ ] La fenêtre se déplace par sa barre de titre.

## 1. Créer une réunion et copier le lien

- [ ] « Nouvelle réunion » (ou ⌘N) : écran de pré-connexion, nom de salle du type « Faon pale jardin · utxswm », lien en dessous.
- [ ] Au premier passage, macOS demande l'accès à la **caméra** puis au **micro**, avec les textes de Void Echo : accepter.
- [ ] L'aperçu de la caméra s'affiche (en miroir), la barre de niveau bouge quand on parle.
- [ ] « Copier le lien » : le bouton passe à « Copié », le lien collé ailleurs est `https://<serveur>/<salle>`.
- [ ] « Entrer dans la réunion » : la réunion Jitsi occupe la fenêtre, sans seconde page de pré-connexion de Jitsi ; le nom choisi apparaît sur votre vignette.
- [ ] Caméra et micro sont actifs dans Jitsi (vignette vidéo, icône micro non barrée).
- [ ] La barre de titre montre le nom de la salle, le serveur, et trois boutons (lien, navigateur, quitter).

## 2. La rejoindre depuis un second appareil ou un navigateur

- [ ] Ouvrir le lien copié sur le second appareil (ou dans Safari / Chrome) et entrer.
- [ ] Chaque côté voit et entend l'autre ; le nom affiché côté Void Echo est celui choisi.
- [ ] Dans Void Echo, « Rejoindre » (⌘J) depuis l'accueil : coller un lien complet, un lien sans `https://`, puis un nom de salle seul → chaque fois l'écran de pré-connexion de la bonne salle.
- [ ] Un lien copié avant d'ouvrir « Rejoindre » est déjà dans le champ.
- [ ] Taper « ma réunion » (espace) → message d'erreur en rouge, rien ne s'ouvre.

## 3. Caméra et micro (autorisations accordées)

- [ ] Pré-connexion : choisir une **autre caméra** et un **autre micro** dans les listes ; l'aperçu et le niveau suivent. Entrer : Jitsi utilise bien ces appareils (Jitsi → Réglages → Audio / Vidéo, ou l'autre participant).
- [ ] Couper caméra et micro **avant d'entrer** (boutons ronds rouges) : on entre caméra et micro coupés ; la lumière verte de la caméra reste éteinte.
- [ ] Réglages → caméra / micro par défaut, « coupé(e) à l'entrée » : repris sur la pré-connexion suivante.
- [ ] Débrancher / brancher un appareil (casque, caméra USB) : les listes se mettent à jour.

## 4. Caméra et micro (autorisations refusées)

- [ ] Réglages Système → Confidentialité et sécurité → Caméra → désactiver Void Echo (macOS peut demander de relancer l'app).
- [ ] Nouvelle réunion : l'aperçu indique « Pas d'accès à la caméra », un encadré « Void Echo n'a pas accès à la caméra. » propose **Ouvrir Réglages Système**, qui ouvre directement le panneau Caméra.
- [ ] Entrer quand même : la réunion fonctionne, micro seul ; si Jitsi demande la caméra (clic sur la caméra dans Jitsi), une bannière en haut de la réunion le signale avec le même bouton ; elle se ferme avec ✕.
- [ ] Même chose pour le micro (panneau Micro).
- [ ] Réglages de Void Echo → Autorisations : « Refusé » et le bouton ; réautoriser, revenir dans l'app : « Autorisé ».

## 5. Couper / réactiver micro et caméra

- [ ] ⌘D coupe le micro (icône barrée dans Jitsi, l'autre participant ne vous entend plus) ; ⌘D le réactive.
- [ ] ⌘E coupe la caméra (la lumière verte s'éteint, l'autre côté voit votre avatar) ; ⌘E la réactive.
- [ ] Menu Réunion : les libellés suivent (« Couper le micro » / « Réactiver le micro », idem caméra), y compris après un clic sur les boutons de Jitsi.
- [ ] Les raccourcis marchent aussi juste après avoir cliqué dans la page Jitsi (chat, par exemple).

## 6. Quitter la réunion

- [ ] ⌘W : retour à l'accueil, la fenêtre reste ouverte ; l'autre participant vous voit partir aussitôt ; plus d'indicateur caméra / micro dans la barre des menus.
- [ ] Rejoindre, puis le bouton rouge de Jitsi (raccrocher) : retour à l'accueil.
- [ ] Rejoindre, puis l'icône « téléphone » de la barre de titre : idem.
- [ ] Rejoindre, puis ⌘Q : Void Echo se ferme, l'autre participant vous voit partir aussitôt.
- [ ] Pendant une réunion, ⌘N et ⌘J sont indisponibles (une seule réunion à la fois).

## 7. Retrouver la réunion dans l'historique

- [ ] La réunion est en tête de « Récentes », avec la date (« Aujourd'hui, 15:19 »).
- [ ] Survol : « Copier le lien » (coche de confirmation) et « Rejoindre » ; double-clic : rejoindre.
- [ ] Clic droit → « Retirer de l'historique » : la ligne disparaît.
- [ ] Quitter et relancer : l'historique est conservé.
- [ ] « Vider l'historique » → confirmation → liste vide.

## 8. Changer le serveur dans les réglages

- [ ] Réglages (⌘,) → Serveur Jitsi : taper une autre adresse (ex. `meet.ffmuc.net`) ; le bouton ↩︎ « Revenir à meet.jit.si » apparaît.
- [ ] Nouvelle réunion : le lien est sur le nouveau serveur, la réunion s'y ouvre.
- [ ] L'historique affiche « · meet.jit.si » sur les réunions d'avant ; les rejoindre les ouvre bien sur meet.jit.si.
- [ ] Taper une adresse invalide (« visio exemple ») : message en rouge sous le champ ; une nouvelle réunion reste sur meet.jit.si.
- [ ] Un serveur introuvable (`visio.invalide.example`) : nouvelle réunion → « La réunion n'a pas pu s'ouvrir », Réessayer / Retour à l'accueil.
- [ ] ↩︎ : retour à meet.jit.si.

## 9. meet.jit.si et connexion modérateur

- [ ] Sur meet.jit.si, nouvelle réunion : Jitsi affiche « Asking to join meeting… no moderators have yet arrived ».
- [ ] « Log-in » : une fenêtre de Void Echo s'ouvre (« Sign in with Google / GitHub », « Ouvrir dans le navigateur » en haut à droite).
- [ ] Se connecter (GitHub, puis Google) : la fenêtre se ferme, la salle démarre, caméra et micro s'allument. Noter si Google refuse la connexion dans la vue intégrée.
- [ ] Le second appareil peut alors entrer.

## 10. Couleur d'accent et thème

- [ ] Réglages → Couleur : violet, bleu, vert, orange, rose. Chaque choix s'applique **à chaud** partout : boutons principaux, liens, niveau du micro, icônes de l'historique, interrupteurs, contour des champs.
- [ ] Relancer : le choix est conservé.
- [ ] Thème Clair / Système / Sombre : appliqué à chaud ; le logo reste lisible en clair (arcs plus soutenus).
- [ ] Teinte de la fenêtre et intensité / dégradé : comme dans Void et Void Calendar.

## 11. Partage d'écran

- [ ] Dans la réunion (avec un second participant), bouton de partage de Jitsi : Void Echo demande « Que voulez-vous partager ? ».
- [ ] « Annuler » : rien n'est partagé, Jitsi reste normal.
- [ ] « Une fenêtre… » : le sélecteur de macOS s'ouvre ; survoler une fenêtre → « Share This Window » ; l'autre participant voit cette fenêtre.
- [ ] Arrêter le partage par le bouton de Jitsi, puis par l'icône de partage de la barre des menus : l'autre côté ne voit plus rien, l'indicateur disparaît.
- [ ] « Tout l'écran » : l'écran est partagé sans autre question ; « Switch Screen… » dans la barre des menus permet d'en changer (plusieurs écrans).
- [ ] Le son de l'ordinateur n'est **pas** transmis (limite connue).
- [ ] Bouton « Continuer dans le navigateur » de la barre de titre : Void Echo quitte la salle, le navigateur par défaut l'ouvre.

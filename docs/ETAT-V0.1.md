# État de Void Echo 0.1 — fait, partiel, non fait

Établi le 13 octobre 2026, sur macOS 27.0.1, Xcode 27, MacBook Pro Apple silicon (caméra FaceTime HD, micro Bluetooth « Bose » et micro du MacBook Pro), écran externe. « Vérifié » veut dire constaté en faisant tourner l'app, avec l'état réel de Jitsi lu dans la page (sonde Debug) et, pour la réunion, un second participant dans un navigateur.

## Fait

| Fonction | Vérifié |
|---|---|
| Projet Xcode séparé (`VoidEcho.xcodeproj`, dossiers synchronisés), Swift/SwiftUI + AppKit, aucune dépendance, macOS 14, arm64 | Builds Debug et Release sans avertissement ; app de 1,9 Mo |
| Réunion = page Jitsi dans une `WKWebView` ; aucun code WebRTC | Oui |
| Serveur par défaut meet.jit.si, adresse écrite à un seul endroit (`JitsiServer.defaultAddress`) | Oui (recherche dans le code) |
| Accueil : « Nouvelle réunion », « Rejoindre », liste des récentes | Oui |
| Nouvelle réunion : nom aléatoire lisible (3 mots + suffixe de 6, ≈ 50 bits, générateur sûr), bouton « Copier le lien » | Oui ; lien copié vérifié dans le presse-papiers |
| Rejoindre : lien complet, lien sans `https://`, nom seul, lien d'un autre serveur, tenant JaaS, port ; message d'erreur | Oui (14 cas testés par script, et dans l'app) |
| Lien déjà copié proposé dans le champ Rejoindre | Oui |
| Pré-connexion : nom, caméra, micro, aperçu, niveau du micro, couper caméra / micro avant d'entrer | Oui ; le nom choisi (« Antoine Echo ») et l'état des appareils arrivent chez l'autre participant |
| Entrée avec caméra / micro coupés : respectée | Oui (seule la piste micro existe) |
| Caméra et micro dans la réunion (malgré l'entrée « sans média » imposée par Jitsi) | Oui ; vidéo reçue par le second participant |
| Choix de l'appareil transmis à Jitsi | Oui pour les appareils par défaut (pistes « Bose Antoine », « FaceTime HD Camera ») ; voir *Partiel* |
| ⌘D / ⌘E (clavier réel et menu Réunion), titres du menu à jour | Oui, dans les deux sens ; la caméra coupée est vraiment relâchée |
| ⌘W : quitte la salle, retour à l'accueil, fenêtre ouverte | Oui ; départ vu par l'autre participant en moins de 2 s |
| Raccrocher dans Jitsi → retour à l'accueil | Oui |
| ⌘Q pendant une réunion : départ propre | Oui ; départ vu en moins de 2 s |
| Une seule réunion à la fois | Oui (commandes indisponibles pendant une réunion) |
| Historique (nom, date, serveur), rejoindre, copier, retirer, vider avec confirmation, conservé entre deux lancements | Oui |
| Permissions : clés d'usage, entitlements Sandbox (réseau sortant, caméra, micro), demande macOS sur l'écran de pré-connexion | Oui (demandes macOS acceptées pendant le test) |
| Délégué de capture média : seul le serveur de la réunion obtient caméra et micro, jamais de demande sans réponse | Oui (journal `probe.log`) |
| Notifications, localisation demandées par la page : refusées | Code en place (délégué privé) ; aucune demande observée de Jitsi pendant les tests |
| Fenêtres ouvertes par la page (connexion modérateur meet.jit.si) dans une fenêtre de Void Echo | Oui (« Sign in with Google / GitHub ») ; correction de « Login popup was blocked » |
| Partage d'écran dans la WKWebView | Oui : feuille de choix, partage de tout l'écran, arrêt, sélecteur de fenêtre de macOS, annulation |
| Réglages : serveur (validation, retour à meet.jit.si), nom par défaut, caméra / micro par défaut, coupés à l'entrée, autorisations | Oui pour serveur, nom, toggles ; changement de serveur vérifié par une réunion créée sur le nouveau serveur |
| Couleur d'accent (5, violet par défaut), thème sombre par défaut / clair / système, teinte de la fenêtre : même mécanisme et mêmes clés que la suite | Oui ; changement appliqué partout à chaud, mémorisé |
| Logo et icône originaux (éclipse de Void + écho), textes originaux | Oui ; icône recentrée après retour |
| README, état, checklist | Ce document et les deux autres |

## Partiel

- **Choix d'un appareil autre que celui par défaut** : le mécanisme (noms d'appareils, script injecté) est en place et vérifié avec les appareils par défaut, mais le choix d'un **autre** micro ou d'une autre caméra dans la liste n'a pas été vérifié de bout en bout (l'outil de test ne peut pas ouvrir les menus déroulants). À faire avec la checklist (§ 3).
- **Refus des autorisations dans Réglages Système** : message, bouton « Ouvrir Réglages Système » et bannière dans la réunion sont codés, mais le cas « refusé » n'a pas été provoqué (il faut retirer l'accès dans Réglages Système, ce que le test automatisé ne fait pas). Checklist § 4.
- **Partage d'écran** : la sélection effective d'une fenêtre dans le sélecteur de macOS et l'arrêt par le bouton de Jitsi n'ont pas été faits par le test (interface système) ; le son de l'ordinateur n'est pas partagé.
- **meet.jit.si** : la connexion modérateur (Google / GitHub) n'a pas été faite (elle demande votre compte) ; Google peut refuser une vue web intégrée.
- **« Continuer dans le navigateur »** : codé (quitte la salle puis ouvre le lien dans le navigateur par défaut), non déclenché pendant les tests pour ne pas ouvrir votre navigateur.
- **Erreur de chargement** (serveur introuvable) : écran « La réunion n'a pas pu s'ouvrir » avec Réessayer / Retour codé, non provoqué.
- **Pont avec Jitsi** : repose sur l'objet interne `APP` de Jitsi ; un repli par WebKit existe pour ⌘D / ⌘E, mais l'allumage automatique à l'entrée en dépend.

## Non fait (hors périmètre de la 0.1, comme demandé)

- Comptes et connexion propres à Void Echo.
- Enregistrement des réunions, planification (lien avec Void Calendar), chat hors de Jitsi, IA.
- Réunions multiples en parallèle.
- Jetons JWT (JaaS, serveurs à authentification par jeton).
- Son de l'ordinateur dans le partage d'écran (possible plus tard en reprenant `ShareAudio` de Void).
- Traduction (interface en français, comme la suite).
- Notarisation / signature avec un compte développeur.

## Points relevés en test et corrigés

1. Icône et logo mal centrés (remarque faite pendant le développement) : l'ensemble éclipse + arcs est maintenant centré géométriquement, arcs symétriques autour de l'horizontale.
2. Menus déroulants de la pré-connexion centrés au lieu d'être alignés sur le champ du nom.
3. « Login popup was blocked by your browser » sur meet.jit.si : la page de la réunion peut ouvrir ses fenêtres (dans Void Echo).
4. Caméra et micro jamais ouverts dans la réunion : Jitsi entre « sans média » quand sa pré-connexion est désactivée par le lien ; le pont les allume une fois la salle rejointe.
5. Le script de choix des appareils ne s'installait pas (`navigator.mediaDevices` pas encore utilisable au début du chargement) : il s'installe maintenant sur `MediaDevices.prototype`.
6. ⌘D / ⌘E se fiaient à l'état « coupé » de Jitsi, faux tant qu'aucun appareil n'a été ouvert : ils se fient aux pistes locales.
7. Partage d'écran : accorder « écran » partageait l'écran entier sans choix ; Void Echo demande d'abord quoi partager.
8. Logo : arcs de l'écho presque invisibles en thème clair ; teinte plus soutenue en clair.
9. Barre de titre de la réunion : la barre d'outils système de macOS 26+ entourait le titre et les boutons de capsules « Liquid Glass » (titre rogné). Comme dans Void, la barre est désormais dessinée par l'app (titre centré, boutons à plat sur la couleur du cadre, boutons de fenêtre recentrés, déplacement de la fenêtre par ses zones vides).

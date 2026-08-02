Tâche : Corriger l'apparition physique de TOUS les objets craftés dans CraftingSystem.server.luau.

# Problème 1 : Torche et Lance ne sont pas tenues en main
Actuellement, ces objets sont créés comme de simples Parts dans le Workspace et tombent au sol.
Action :
1. Pour "Torche" et "Lance", crée un vrai objet `Tool` avec un enfant `BasePart` nommé "Handle" (taille raisonnable, ex: 0.5 x 2 x 0.5 pour une torche, 0.3 x 4 x 0.3 pour une lance).
2. `Handle.CanCollide = false` pour ne pas gêner le déplacement du joueur.
3. Parent le `Tool` directement dans `player.Backpack` (PAS dans le Workspace) pour qu'il apparaisse dans l'inventaire et puisse être équipé en main normalement via les touches 1-9 de Roblox.
4. Pour la Torche : ajoute un `PointLight` sur le Handle pour qu'elle éclaire vraiment une fois équipée.
5. Pour la Lance : ajoute une détection de contact simple (`Handle.Touched`) qui inflige 25 dégâts à un monstre si le Tool est équipé (`tool.Parent == character`) et que le joueur clique/attaque (utilise `tool.Activated:Connect(...)` pour déclencher l'attaque plutôt qu'un Touched permanent, plus fiable en Roblox).

# Problème 2 : Barricade, Piège et Fortification ne sont pas visibles
Action :
1. Crée (si elle n'existe pas déjà) une zone de construction nommée "CraftZone" dans le Workspace : une Part invisible de taille 40x1x40 positionnée au centre de la place du village (à côté du feu de camp existant, coordonnées Vector3.new(0, 0.5, 0) à ajuster selon la position réelle de WorldBuilder).
2. Pour "Barricade" et "Piege" : au moment du craft, calcule une position devant le joueur (`HumanoidRootPart.CFrame.LookVector * 5`), MAIS clamp cette position pour qu'elle reste impérativement à l'intérieur des limites de "CraftZone" (si le calcul sort de la zone, place l'objet au bord le plus proche de la zone plutôt qu'à la position calculée).
3. Assure-toi que ces Parts sont bien visibles : `Transparency = 0`, une couleur contrastée (marron pour la barricade, gris foncé/rouge pour le piège), et `Anchored = true` pour qu'elles ne tombent pas à travers le sol.
4. Pour "Fortification" : en plus de soigner la porte (+100 Health), ajoute un effet visuel temporaire clairement visible sur la porte réparée (par exemple, fais clignoter sa couleur en vert pendant 1 seconde via TweenService, ou fait apparaître un `ParticleEmitter` bref) pour que le joueur voie concrètement que sa fortification a eu un effet.

# Contraintes
- Conserve impérativement toute la logique réseau existante (RemoteEvents, vérification des ressources, vérification de phase DAY_PHASE).
- Code défensif : si HumanoidRootPart ou CraftZone est introuvable, log un warn() et annule l'action proprement, ne crashe jamais.
- Rendu : réécris l'intégralité de CraftingSystem.server.luau avec ces corrections.

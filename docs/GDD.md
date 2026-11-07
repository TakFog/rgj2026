# BalanSea — Game Design Document (MVP)

> Game jam, tema **SUBIRE**. Gestionale real-time di una barriera corallina, vista dall'alto 2D, Godot 4.x (GDScript).
> Obiettivo: mantenere l'equilibrio dell'ecosistema il più a lungo possibile.

---

## 1. Pilastri

1. **Equilibrio**: ogni elemento serve, ogni eccesso fa danni. Se una popolazione arriva a zero, l'ecosistema collassa.
2. **Subire**: il corallo non fa niente, subisce e basta. Il giocatore lo protegge in modo indiretto.
3. **Real-time, ibrido griglia/spazio libero**: niente turni. **Coralli, alghe e nidi si piazzano su una griglia** (anche le alghe si espandono per celle). **Pesci e minacce si muovono liberi** con la fisica 2D di Godot e urtano le celle occupate.
4. **Visuale quasi dall'alto**: la simulazione avviene in un piano logico visto dall'alto; quello che si vede a schermo è una sua proiezione leggermente inclinata, con angolo regolabile (§4.1).

## 2. Loop di gioco

```
temperatura ↑ ──► alghe crescono più in fretta, più minacce, pesci più lenti
	 ▲
	 │ (rallentata dalle celle di corallo vivo, mai fermata)
	 │
inventario ──► piazzi corallo / alga / nido
pesci ──► li mandi a mangiare alghe (o muoiono di fame) e a fecondare nidi
alghe ──► si espandono, soffocano i coralli
minacce ──► CO2, buste, cicloni (annunciati prima di entrare)
```

- Troppe alghe → soffocano i coralli → coralli a zero → game over
- Troppi pesci → finiscono le alghe → alghe a zero → game over
- Troppi coralli → i pesci restano bloccati e non arrivano al cibo → muoiono di fame → game over
- Pochi pesci → bisogna fecondare i nidi in fretta

## 3. Condizioni di fine partita e punteggio

- **Survival a punteggio, senza vittoria.**
- Le popolazioni controllate sono quattro, contate **sulla mappa**: **coralli, alghe, pesci, nidi**.
- **Timeout di collasso**: quando una popolazione arriva a 0 **non** si perde subito. Parte un conto alla rovescia di `collapse_grace_seconds` (**7 s**) solo per quella popolazione.
  - Se la popolazione torna sopra 0 prima della scadenza, il conto alla rovescia si annulla. Se in seguito torna a 0, il conto riparte da capo.
  - Se il conto arriva a 0 → **game over**.
  - Ogni popolazione ha un suo conto alla rovescia indipendente; se ne scadono più di uno, il primo che scade fa perdere.
  - Il tempo si ferma quando il gioco è in pausa.
- Come ci si salva, per ogni popolazione:
  - **Pesci**: un nido con uova che si schiudono entro il timeout (*sono morti tutti i pesci, ma le uova stanno per schiudersi → ti salvi*). I pesci non arrivano dall'inventario.
  - **Alghe / coralli / nidi**: piazzandone uno dall'inventario, se c'è o se uno slot si ricarica in tempo.
- Interfaccia: mentre è attivo un conto alla rovescia, al centro in alto compare un avviso rosso con l'icona della popolazione e i secondi rimasti. Per i pesci, se c'è un nido con uova, l'avviso mostra anche il tempo che manca alla schiusa, così il giocatore capisce subito se si salverà.
- **Punteggio** = secondi sopravvissuti (MVP). Mostrato nell'interfaccia e nella schermata di game over, che mostra anche la popolazione collassata, i conteggi finali e il miglior tempo salvato.

## 4. Mappa iniziale

Fissa, non randomica, costruita a mano nella scena `levels/Level01.tscn`:

- 3 pesci adulti (fecondi)
- 1 nido vuoto
- 5 alghe
- 5 coralli di forme diverse

Area di gioco delimitata da muri invisibili (StaticBody2D).

### Griglia
- Celle logiche da `cell_size` = 32 unità. Area di gioco di **20 × 20 celle** (640 × 640 unità logiche; la dimensione a schermo dipende dall'inclinazione scelta).
- Tutte le misure di questo documento (raggi, velocità, distanze) sono in **unità logiche**, non in pixel a schermo.
- La griglia vale **solo per gli oggetti fermi** (coralli, alghe, nidi): ogni cella contiene al massimo uno di questi oggetti.
- Pesci e minacce **non** usano la griglia: si muovono in coordinate libere.
- Visualizzazione: una griglia leggera compare solo mentre stai piazzando un oggetto.

### 4.1 Visuale (quasi dall'alto, proiezione obliqua)
La visuale **non è isometrica pura**: è quasi dall'alto, in proiezione obliqua. Il codice non dipende dall'angolo, quindi il designer può ritoccarlo in qualsiasi momento.

- **Due livelli separati:**
  - **Mondo logico** (`World`): piano visto dall'alto, celle quadrate. Qui stanno griglia, fisica 2D, collisioni, movimento, regole. Questo livello non viene disegnato (si vede solo nel debug overlay).
  - **Vista** (`View`): sprite in un nodo con `y_sort_enabled`. Ogni sprite segue a ogni frame la proiezione della posizione del suo corpo logico.
- **Stile scelto dal designer: proiezione obliqua** `/__/`. Il fondale è un parallelogramma: i bordi orizzontali restano orizzontali e piatti, quelli in profondità salgono verso destra a **45°**. Non è isometrico (niente rombi) e non è una semplice rotazione: è un **taglio obliquo** della griglia.
- **Proiezione parametrica**, in un solo punto (`View.gd`): una trasformazione affine (`Transform2D`) definita da due vettori in `balance.tres`:
  - `view_x_axis`: dove finisce a schermo un passo di 1 unità verso destra nel mondo. Default `(1, 0)`.
  - `view_y_axis`: dove finisce a schermo un passo di 1 unità verso il basso nel mondo (verso chi guarda). Per `/__/` a 45°: `(−d, d)`, dove `d` è lo schiacciamento della profondità. Default `d = 0.5` (circa 0.71 unità di lunghezza a schermo).
  - `screen = world.x × view_x_axis + world.y × view_y_axis` (moltiplicato per `pixels_per_unit`).
  - Il mouse usa `affine_inverse()` (schermo → mondo → cella) per i clic e il piazzamento.
  - La stessa formula copre anche le altre visuali, se il designer cambia idea: dall'alto puro `x=(1,0), y=(0,1)`; quasi dall'alto `x=(1,0), y=(0,0.8)`; isometrico `x=(1,0.5), y=(−1,0.5)`.
- **Cosa cambia se si ritocca l'inclinazione**: solo i due vettori, le dimensioni degli sprite e la loro **base**. Regole, fisica, griglia, input e bilanciamento restano uguali.
- **Convenzione per gli asset** (da concordare subito col designer, indipendentemente dall'angolo): ogni sprite ha il **punto di ancoraggio alla base**, cioè dove l'oggetto "tocca il fondale", al centro della cella o del corpo. Gli elementi alti (coralli) crescono verso l'alto dello schermo a partire da quel punto.
- **Ordine di disegno**: Y-sort sulla coordinata a schermo del punto di ancoraggio. I coralli di più celle si disegnano **una cella alla volta**, così un pesce può passare davanti a una parte del corallo e dietro a un'altra. Più la visuale è dall'alto, meno questo problema si nota.
- **Leggibilità**: se un pesce o il nido è coperto da un corallo, si vede la sua sagoma attraverso il corallo (shader di contorno). L'area di clic dei pesci è più grande dello sprite.
- **Minacce**: hanno un'ombra a terra che mostra quali celle stanno toccando.

## 5. Elementi

### 5.1 Inventario
- **4 slot** fissi.
- Quando usi uno slot, lo slot si **ricarica dopo `slot_refill_seconds` (14 s)** con un oggetto estratto a caso con pesi:
  - Corallo: peso 40
  - Alga: peso 40
  - Nido: peso `nest_base_weight / (1 + nidi_in_mappa + nidi_in_inventario)` (base 20). Meno nidi hai, più è probabile che ne arrivi uno.
- Piazzamento: clicchi lo slot (o premi **1-4**, tastiera numerica inclusa) e sotto il mouse compare un'anteprima trasparente **agganciata alla cella**: **verde** se tutte le celle sono valide, **rossa** altrimenti. Clic sinistro conferma, clic destro o Esc annulla.
- Una cella è valida se è dentro la mappa, se è vuota e se **nessun pesce o minaccia ci si trova sopra in quel momento** (così non si incastrano corpi dentro un ostacolo).

### 5.2 Corallo — *subisce*
- Ha forme diverse: **gruppi di celle** in stile polimino (es. 1×1, 2×1, L da 3, quadrato 2×2, T da 4). Nell'MVP la forma non si ruota.
- È un ostacolo solido per i pesci: ogni cella ha una collisione quadrata.
- L'ossigeno appartiene **al corallo intero**, non alla singola cella. Quando muore libera tutte le sue celle.
- **Ossigeno** da 0 a 100. A 0 si **sgretola**: animazione, poi viene rimosso.
- **Recupero lento**: `+coral_regen_per_sec` (0.3/s) a temperatura ambiente. Il recupero dipende dalla temperatura e diventa **negativo** con l'acqua calda (`coral_regen_hot_per_sec`, −1.5/s a T=1): i coralli muoiono in fretta se il mare si surriscalda (il recupero diventa negativo già sopra T≈0.17).
- Danni (vedi tabella delle interazioni): alga che si espande addosso, CO2, busta, ciclone. **Tutti i danni sono istantanei e avvengono al contatto**: non esistono danni al secondo.
- Rallenta la salita della temperatura **in proporzione alle celle che occupa** (§6): un corallo grande protegge di più dal caldo, ma blocca di più i pesci.

### 5.3 Alga
- Occupa **1 cella**, ostacolo solido per i pesci (collisione quadrata a cella piena, quindi i muri di alghe non hanno buchi).
- **Espansione**: ogni `algae_growth_interval` (con variazione casuale ±20%, ridotto dalla temperatura) l'alga prova a generarne una nuova:
  1. prova le **4 celle adiacenti** (sopra, sotto, sinistra, destra) in **ordine casuale**;
  2. controlla la cella:
	 - **vuota** → nasce la nuova alga;
	 - **corallo** → l'alga non nasce, il corallo perde `algae_coral_damage` ossigeno;
	 - **qualsiasi altra cosa** (alga, nido, fuori mappa, pesce o minaccia sopra la cella) → passa alla cella adiacente successiva.
  3. Se **nessuna** delle 4 celle è utilizzabile, l'espansione si ferma. Al prossimo intervallo l'alga riprova, perché nel frattempo una cella potrebbe essersi liberata (es. un pesce ha mangiato un'alga vicina).
- Tetto massimo di alghe in gioco: `algae_max_count` (120), sia per le prestazioni sia per il bilanciamento.
- Può essere mangiata dai pesci.

### 5.4 Pesce
- CharacterBody2D, piccolo (raggio 10 unità). **I pesci non si scontrano tra loro**, ma si scontrano con alghe, coralli e muri.
- **Stati**:
  - `WANDER`: nuota a caso. Sceglie una direzione, nuota per un po', ne cambia. Se tocca un ostacolo, cambia direzione. **Non feconda.** Quando la fame supera `seek_food_threshold` (50%) passa a `SEEKING_FOOD`.
  - `SEEKING_FOOD`: il pesce affamato calcola un percorso verso l'**alga più vicina raggiungibile** (distanza lungo il percorso, non in linea d'aria) e ci va; quando la tocca → `EATING`. Se nessuna alga è raggiungibile (es. chiuso dai coralli) continua a girare e riprova ogni `seek_retry_seconds` (1 s). Se l'alga sparisce prima che arrivi, torna a `WANDER`. Un ordine del giocatore ha sempre la precedenza.
  - `ORDERED`: il giocatore fa clic sinistro sul pesce per selezionarlo (area di clic più grande del pesce) e poi clic sinistro sul punto di arrivo. Il pesce **calcola un percorso** sulla griglia (A*) che aggira coralli e alghe (i nidi si attraversano) e lo segue. Il percorso viene **semplificato** (si saltano le celle intermedie quando la linea retta è libera, con il raggio del pesce di margine), quindi in acqua libera il pesce va dritto, senza zig-zag sulla griglia. Il pesce **nuota in curva**: la direzione cambia gradualmente con un raggio di virata `fish_turn_radius` (16), che si stringe vicino al punto di arrivo per non girargli intorno; anche nel `WANDER` i cambi di direzione sono curvi. Se sfiora un ostacolo ci scivola lungo; solo un urto frontale conta come blocco (o come arrivo sull'alga da mangiare). Se il punto è dentro un ostacolo o in una zona chiusa, va alla cella raggiungibile più vicina e punta verso il punto finché non tocca l'ostacolo. Se un ostacolo imprevisto blocca il percorso, lo ricalcola una volta; se è ancora bloccato **si ferma**.
	- Se si è fermato contro un'**alga** → `EATING`.
	- Se arriva sopra un **nido vuoto** ed è adulto → `FERTILIZING`.
	- Altrimenti resta fermo `idle_after_order_seconds` (2 s) e poi torna a `WANDER`.
  - `EATING`: dopo `eat_seconds` (3 s) l'alga viene rimossa e la fame si azzera. Poi torna a `WANDER`. *Un pesce circondato dalle alghe può uscirne mangiando.*
  - `FERTILIZING`: deve restare fermo sul nido `fertilize_seconds` (3 s). Se se ne va prima (nuovo ordine), la fecondazione non avviene. Se va a buon fine, il nido passa a `EGGS` e il pesce torna a `WANDER`, libero di andarsene.
- **Fame**: da 0 a `starve_seconds` (45 s). Barra visibile sopra il pesce quando supera il 50%: è piena a fame 0 e si svuota man mano che il pesce si affama, come la barra di sazietà del predatore. Il colore va dal verde (pieno) al rosso (quasi vuoto); sopra il 75% compare un "!" lampeggiante. Al massimo il pesce muore.
- **Età**: nasce giovane e diventa fecondo dopo `maturity_seconds` (60 s). Il pesce giovane si riconosce a vista (sprite più piccolo).
- La velocità è ridotta dalla temperatura.

### 5.5 Nido
- Occupa **1 cella**. È un Area2D, quindi i pesci possono passarci sopra.
- Stati: `EMPTY` → (fecondazione) → `EGGS` → dopo `hatch_seconds` (20 s) nascono `hatch_count` (2) pesci giovani → `EMPTY`.
- Con il caldo le uova possono morire prima della schiusa. La probabilità è interpolata sulla temperatura: `egg_death_chance_cold` = −0.2 a T=0 (clampata a 0, quindi all'inizio non muoiono mai) e `egg_death_chance_hot` = 0.85 a T=1 (85% di probabilità sull'intera incubazione).
- Si ottiene dall'inventario con probabilità bassa (vedi §5.1).

## 6. Temperatura
- Valore normalizzato `T` da 0 a 1 (mostrato come °C sul termometro in alto a destra).
- **Sale sempre**: `dT/dt = temp_base_rate × (1 − coral_slowdown)`
  - `coral_slowdown = min(celle_di_corallo × temp_slow_per_cell, temp_max_slowdown)` con `temp_max_slowdown` = 0.45, quindi la temperatura **non si ferma mai e non scende mai**.
  - `celle_di_corallo` = numero totale di celle occupate da coralli vivi, letto da `GridModel`. Default `temp_slow_per_cell` = 0.03, quindi il rallentamento massimo si raggiunge con 15 celle di corallo.
  - `temp_base_rate` (0.004) è tarato in modo che, senza coralli, si arrivi a T=1 in circa 4 minuti; con il rallentamento massimo dei coralli servono circa 7 minuti e mezzo.
- Effetti (interpolazione lineare in base a T):

| Effetto | T = 0 | T = 1 |
|---|---|---|
| Intervallo di crescita alghe | 20 s | 5 s |
| Intervallo di spawn CO2 | 22 s | 5 s |
| Intervallo di spawn ciclone | 70 s | 18 s |
| Velocità pesci | 100% | 35% |
| Recupero ossigeno dei coralli | +0.3/s | −1.5/s |
| Probabilità che le uova muoiano prima della schiusa | 0% (valore freddo negativo, azzerato) | 85% |

- Le buste di plastica hanno una frequenza fissa (`bag_spawn_interval` 28 s).

## 7. Minacce

Tutte le minacce sono **Area2D** che si muovono liberamente (non seguono la griglia) ed entrano dal bordo dello schermo. Colpiscono un oggetto fermo quando la loro forma si sovrappone a una delle sue celle. **Niente avvisi**: la zona giocabile (la griglia) è un'**isola sottomarina** al centro dello schermo, circondata da fondale aperto non giocabile. La camera ha uno zoom fisso (`zoom` in `view_settings.tres`) che lascia visibile questo fondale: le minacce nascono appena fuori dallo schermo, puntano verso un punto a caso dell'isola e il giocatore le vede arrivare attraverso il fondale. Quando escono dallo schermo vengono rimosse.

### 7.1 CO2
- Nube (raggio 60 unità), si muove **quasi dritta con curve casuali** (direzione + rumore sull'angolo).
- Fuori dall'isola (fondale aperto) il rumore è ridotto (`co2_outside_turn_scale`, 10%) e la direzione viene forzata verso il centro dell'isola: la nube attraversa il fondale quasi in linea retta e punta sempre verso la zona giocabile, iniziando a curvare solo una volta dentro.

### 7.2 Busta di plastica
- Lenta, si muove in modo **più casuale** della CO2 (cambi di direzione più ampi e frequenti).
- Puramente estetico: la sprite ruota attorno al suo centro con verso e velocità casuali, come una busta nella corrente, e non ha ombra a terra.

### 7.3 Ciclone marino
- Raggio 40 unità, veloce, va **dritto**.

### 7.4 Pesce predatore (carnivoro)
- **Feature flag**: `predator_enabled` in `balance_actors.tres` (se il designer non realizza l'asset, si spegne da lì).
- Arriva ogni `predator_interval` (45 s), al massimo `predator_max_count` (1) alla volta, dal bordo dello schermo come le altre minacce.
- Caccia **pesci adulti, pesci giovani e uova** finché non è sazio (`predator_satiety`, 8), poi se ne va. Se non si sazia entro `predator_hunt_seconds` (45 s passati sull'isola) se ne va comunque.
- Sazietà per preda: giovane `predator_juvenile_satisfaction` (1) < adulto `predator_adult_satisfaction` (2) < uova = giovane × uova che si schiuderebbero (`nest_hatch_count`, quindi 2). Le uova sono la preda preferita: fanno perdere più tempo al giocatore.
- Sceglie la preda con il punteggio più alto: **sazietà / distanza lungo il percorso**. Ignora le prede che non può raggiungere. Ricalcola preda e percorso ogni `predator_replan_seconds` (0.5 s), perché i pesci si muovono.
- È **grande** (`predator_radius` 22, più di mezza cella): non passa nei **corridoi larghi una cella** tra i coralli, dove i pesci invece passano. **Solo i coralli lo fermano**: passa sopra alghe e nidi, quindi le alghe non proteggono i pesci. Il giocatore può proteggere pesci e nidi costruendo corridoi stretti di corallo. Il percorso si calcola sugli angoli della griglia: un angolo è percorribile solo se le 2×2 celle intorno non contengono coralli.
- Dopo ogni morso si ferma `predator_bite_pause_seconds` (1 s). Il caldo lo rallenta come gli altri pesci.
- È un corpo sul layer delle minacce: non si può piazzare nulla sopra di lui e il ciclone lo spazza via.

### 7.5 Tartaruga marina (aiutante)
- **Feature flag**: `turtle_enabled` in `balance_actors.tres` (default `true`).
- Arriva ogni `turtle_interval` (90 s), al massimo `turtle_max_count` (1) alla volta, dal bordo dello schermo come le minacce. Non è una minaccia: aiuta il giocatore.
- **Priorità**: prima difende i pesci, poi pulisce. Una minaccia conta solo se è **vicina** (distanza in linea d'aria): un predatore che sta cacciando entro `turtle_predator_aggro_radius` (160 = 5 celle) o una busta di plastica entro `turtle_bag_aggro_radius` (320 = 10 celle). Tra quelle nel proprio raggio va verso la **minaccia raggiungibile più vicina** lungo il percorso; una volta puntata la insegue finché non la elimina, anche se esce dal raggio. Se non ce ne sono, verso l'**alga raggiungibile più vicina**. Ricalcola ogni `turtle_replan_seconds` (0.5 s); mentre mangia un'alga la lascia se compare una minaccia nel suo raggio.
- **Predatore**: gli va addosso e lo allontana (il predatore smette di cacciare e lascia l'isola). La tartaruga resta.
- **Busta**: la elimina toccandola, poi **se ne va**.
- **Alghe**: le mangia in `turtle_eat_seconds` (0.6 s), molto più in fretta dei pesci (`eat_seconds` 3 s). Con `turtle_max_algae` > 0 se ne va dopo averne mangiate tante (0 = nessun limite).
- Se ne va comunque dopo `turtle_stay_seconds` (30 s passati sull'isola).
- È **grande** come il predatore (`turtle_radius` 20) e usa lo stesso percorso sugli angoli della griglia: **solo i coralli la fermano**, non entra nei corridoi larghi una cella. Più veloce del predatore (`turtle_speed` 70) per poterlo raggiungere; il caldo la rallenta come gli altri pesci.
- È un corpo sul layer delle minacce (non si può piazzare nulla sopra di lei) ma le minacce e il ciclone la ignorano.

## 8. Tabella delle interazioni

Le combinazioni non elencate **non fanno nulla**.

| Agente | Bersaglio | Effetto |
|---|---|---|
| Alga (espansione) | Corallo | Corallo −`algae_coral_damage` (10) ossigeno |
| CO2 | Corallo | Corallo −`co2_coral_damage` (50) ossigeno al primo contatto (basta toccare una qualsiasi delle sue celle), la nube **sparisce**. Con `co2_dies_on_coral = false` la nube invece prosegue e danneggia ogni corallo una sola volta |
| CO2 | Alga | La CO2 viene **assorbita** (sparisce) e l'alga **si espande subito** |
| CO2 | Nido con uova | Le uova muoiono, il nido torna `EMPTY` |
| Busta | Pesce | Il pesce **muore**, la busta resta |
| Busta | Corallo | Corallo −`bag_coral_damage` (35) ossigeno, la busta **sparisce** |
| Ciclone | Pesce / Alga | Distrutti |
| Ciclone | Nido | **Distrutto** |
| Ciclone | CO2 / Busta | Rimosse |
| Predatore | Pesce | Mangiato (sazietà giovane/adulto) |
| Predatore | Nido con uova | Le uova vengono mangiate, il nido torna `EMPTY` (sazietà = giovane × uova) |
| Ciclone | Predatore | Rimosso |
| Tartaruga | Predatore | Il predatore smette di cacciare e lascia l'isola |
| Tartaruga | Busta | La busta viene rimossa, la tartaruga se ne va |
| Tartaruga | Alga | Mangiata in `turtle_eat_seconds` |
| Ciclone | Corallo | Il corallo **muore**, il ciclone **sparisce** |

Danni dal più debole al più forte: alga (10) < busta (35) < CO2 (50). Tutti i danni sono **istantanei al contatto**, nessuno è al secondo.

## 9. Interfaccia
- **In alto a destra**: termometro.
- **In alto al centro**: punteggio / tempo.
- **In basso**: 4 slot dell'inventario, con il numero della scorciatoia (**1-4**) e il tempo di ricarica mostrato come radiale.
- **Pausa**: Spazio / Esc. Mentre sei in pausa non puoi piazzare oggetti.
- **Tutorial**: al primo avvio, dopo Gioca, una schermata mostra tre reazioni animate della barriera (pesce/nido, CO2/alga, alga/corallo) e, accanto, l'elenco completo delle interazioni (§8). Sempre riapribile da "Come si gioca".
- **Debug overlay** (F3): tutti i valori di bilanciamento in tempo reale, raggi di collisione, stati dei pesci.

## 10. Architettura Godot

```
balansea/
├── project.godot
├── autoload/
│   ├── GameState.gd       # conteggi, punteggio, segnali, game over
│   └── Balance.gd         # espone data/balance.tres
├── data/
│   ├── balance.gd         # class_name BalanceData extends Resource
│   ├── balance.tres       # tutti i parametri tarabili
│   └── coral_shapes/      # PackedScene o Resource con i poligoni
├── systems/
│   ├── TemperatureSystem.gd
│   ├── ThreatSpawner.gd   # spawn dal bordo dello schermo
│   ├── InventorySystem.gd
│   ├── PlacementController.gd
│   ├── GridModel.gd       # occupazione celle: Dictionary[Vector2i → entità], cell↔world, adiacenti
│   └── View.gd            # proiezione mondo↔schermo parametrica (Transform2D obliqua)
├── entities/
│   ├── coral/  Coral.tscn  (StaticBody2D, layer CORAL)
│   ├── algae/  Algae.tscn  (StaticBody2D, layer ALGAE)
│   ├── fish/   Fish.tscn   (CharacterBody2D, layer FISH, mask WALL|CORAL|ALGAE)
│   ├── nest/   Nest.tscn   (Area2D, layer NEST)
│   └── threats/ CO2.tscn  Bag.tscn  Cyclone.tscn  (Area2D, layer THREAT)
├── levels/
│   └── Level01.tscn       # mappa iniziale fissa
├── ui/  HUD.tscn  Inventory.tscn  Thermometer.tscn  GameOver.tscn
└── main/ Main.tscn
```

**Physics layers**: 1 WALL, 2 CORAL, 3 ALGAE, 4 FISH, 5 NEST, 6 THREAT.

**Regole tecniche**:
- Nessun RigidBody: i pesci sono CharacterBody2D (`move_and_collide`), alghe e coralli sono StaticBody2D, nidi e minacce sono Area2D. Il comportamento resta controllabile.
- Ogni entità si registra in un gruppo (`corals`, `algae`, `fish`, `nests`) e `GameState` conta i membri dei gruppi.
- Espansione delle alghe e validità del piazzamento si leggono da `GridModel` (veloce, testabile senza scena). Solo il controllo "c'è un pesce o una minaccia sopra questa cella?" usa `PhysicsDirectSpaceState2D.intersect_shape`.
- Gli oggetti fermi si registrano in `GridModel` quando nascono e si rimuovono quando muoiono; la loro collisione fisica è costruita a partire dalle celle che occupano.
- Tutti i timer di gioco si basano sul `delta` del processo, così la pausa funziona con `get_tree().paused`.
- Ogni entità è una scena con un corpo logico (in `World`) e un nodo visivo (in `View`). Lo script dell'entità crea il nodo visivo e lo distrugge quando l'entità muore. Il nodo visivo legge `View.to_screen(body.global_position)` in `_process`.

## 11. Tappe

| # | Tappa | Risultato |
|---|---|---|
| M0 | Progetto (renderer Compatibility), Main, GridModel, View (proiezione parametrica), World/View separati, Level01 fisso, muri, camera | scena vuota giocabile |
| M1 | Corallo + alga: espansione, ossigeno, recupero, sgretolamento | equilibrio alghe/coralli |
| M2 | Pesce: wander, selezione, ordine dritto, mangiare, fame | ciclo pesci–alghe |
| M3 | Nido: fecondazione, schiusa, maturità | ciclo di vita |
| M4 | Inventario + piazzamento + GameState + game over + punteggio | **prima build giocabile** |
| M5 | Minacce (visibili sul fondale attorno all'isola) + tabella delle interazioni | pressione esterna |
| M6 | Temperatura + rallentamento dai coralli | curva di difficoltà |
| M7 | Grafica, suoni, debug overlay, bilanciamento | rifinitura |

## 12. Domande aperte
- I parametri numerici sono solo un punto di partenza da verificare in playtest.
- `collapse_grace_seconds` (7 s) rispetto a `hatch_seconds` (20 s): con questi valori le uova salvano solo se sono state deposte almeno 13 s prima della morte dell'ultimo pesce. Va verificato in playtest.
- Il punteggio deve premiare i coralli vivi (es. punti/s = numero di coralli)?

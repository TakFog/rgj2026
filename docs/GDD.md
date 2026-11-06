# Ideologia Marina — Game Design Document (MVP)

> Game jam, tema **SUBIRE**. Gestionale real-time di una barriera corallina, vista dall'alto 2D, Godot 4.x (GDScript).
> Obiettivo: mantenere l'equilibrio dell'ecosistema il più a lungo possibile.

---

## 1. Pilastri

1. **Equilibrio**: ogni elemento serve, ogni eccesso fa danni. Se una popolazione arriva a zero, l'ecosistema collassa.
2. **Subire**: il corallo non fa niente, subisce e basta. Il giocatore lo protegge in modo indiretto.
3. **Real-time, ibrido griglia/spazio libero**: niente turni. **Coralli, alghe e nidi si piazzano su una griglia** (anche le alghe si espandono per celle). **Pesci e minacce si muovono liberi** con la fisica 2D di Godot e urtano le celle occupate.

## 2. Loop di gioco

```
temperatura ↑ ──► alghe crescono più in fretta, più minacce, pesci più lenti
     ▲
     │ (rallentata dai coralli vivi, mai fermata)
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
- **Timeout di collasso**: quando una popolazione arriva a 0 **non** si perde subito. Parte un conto alla rovescia di `collapse_grace_seconds` (**10 s**) solo per quella popolazione.
  - Se la popolazione torna sopra 0 prima della scadenza, il conto alla rovescia si annulla. Se in seguito torna a 0, il conto riparte da capo.
  - Se il conto arriva a 0 → **game over**.
  - Ogni popolazione ha un suo conto alla rovescia indipendente; se ne scadono più di uno, il primo che scade fa perdere.
  - Il tempo si ferma quando il gioco è in pausa.
- Come ci si salva, per ogni popolazione:
  - **Pesci**: un nido con uova che si schiudono entro il timeout (*sono morti tutti i pesci, ma le uova stanno per schiudersi → ti salvi*). I pesci non arrivano dall'inventario.
  - **Alghe / coralli / nidi**: piazzandone uno dall'inventario, se c'è o se uno slot si ricarica in tempo.
- Interfaccia: mentre è attivo un conto alla rovescia, al centro in alto compare un avviso rosso con l'icona della popolazione e i secondi rimasti. Il contatore di quella popolazione lampeggia. Per i pesci, se c'è un nido con uova, l'avviso mostra anche il tempo che manca alla schiusa, così il giocatore capisce subito se si salverà.
- **Punteggio** = secondi sopravvissuti (MVP). Mostrato nell'interfaccia e nella schermata di game over.

## 4. Mappa iniziale

Fissa, non randomica, costruita a mano nella scena `levels/Level01.tscn`:

- 3 pesci adulti (fecondi)
- 1 nido vuoto
- 5 alghe
- 5 coralli di forme diverse

Area di gioco delimitata da muri invisibili (StaticBody2D).

### Griglia
- Celle da `cell_size` = 32 px. Area di gioco di **36 × 20 celle** (1152 × 640 px).
- La griglia vale **solo per gli oggetti fermi** (coralli, alghe, nidi): ogni cella contiene al massimo uno di questi oggetti.
- Pesci e minacce **non** usano la griglia: si muovono in coordinate libere.
- Visualizzazione: una griglia leggera compare solo mentre stai piazzando un oggetto.

## 5. Elementi

### 5.1 Inventario
- **4 slot** fissi.
- Quando usi uno slot, lo slot si **ricarica dopo `slot_refill_seconds` (8 s)** con un oggetto estratto a caso con pesi:
  - Corallo: peso 50
  - Alga: peso 40
  - Nido: peso `nest_base_weight / (1 + nidi_in_mappa + nidi_in_inventario)` (base 20). Meno nidi hai, più è probabile che ne arrivi uno.
- Piazzamento: clicchi lo slot e sotto il mouse compare un'anteprima trasparente **agganciata alla cella**: **verde** se tutte le celle sono valide, **rossa** altrimenti. Clic sinistro conferma, clic destro o Esc annulla.
- Una cella è valida se è dentro la mappa, se è vuota e se **nessun pesce o minaccia ci si trova sopra in quel momento** (così non si incastrano corpi dentro un ostacolo).

### 5.2 Corallo — *subisce*
- Ha forme diverse: **gruppi di celle** in stile polimino (es. 1×1, 2×1, L da 3, quadrato 2×2, T da 4). Nell'MVP la forma non si ruota.
- È un ostacolo solido per i pesci: ogni cella ha una collisione quadrata.
- L'ossigeno appartiene **al corallo intero**, non alla singola cella. Quando muore libera tutte le sue celle.
- **Ossigeno** da 0 a 100. A 0 si **sgretola**: animazione, poi viene rimosso.
- **Recupero lento**: `+coral_regen_per_sec` (0.5/s) sempre.
- Danni (vedi tabella delle interazioni): alga che si espande addosso, CO2, busta, ciclone.
- Rallenta la salita della temperatura (§6).

### 5.3 Alga
- Occupa **1 cella**, ostacolo solido per i pesci (collisione quadrata a cella piena, quindi i muri di alghe non hanno buchi).
- **Espansione**: ogni `algae_growth_interval` (con variazione casuale ±20%, ridotto dalla temperatura) l'alga prova a generarne una nuova:
  1. sceglie a caso una delle **4 celle adiacenti** (sopra, sotto, sinistra, destra) non ancora provate;
  2. controlla la cella:
     - **vuota** → nasce la nuova alga;
     - **corallo** → l'alga non nasce, il corallo perde `algae_coral_damage` ossigeno;
     - **qualsiasi altra cosa** (alga, nido, fuori mappa, pesce o minaccia sopra la cella) → riprova con un'altra cella adiacente, **al massimo 3 tentativi**, poi l'espansione fallisce.
- Tetto massimo di alghe in gioco: `algae_max_count` (300), sia per le prestazioni sia per il bilanciamento.
- Può essere mangiata dai pesci.

### 5.4 Pesce
- CharacterBody2D, piccolo (raggio 10 px). **I pesci non si scontrano tra loro**, ma si scontrano con alghe, coralli e muri.
- **Stati**:
  - `WANDER`: nuota a caso. Sceglie una direzione, nuota per un po', ne cambia. Se tocca un ostacolo, cambia direzione. **Non mangia e non feconda.**
  - `ORDERED`: il giocatore fa clic sinistro sul pesce per selezionarlo (area di clic più grande del pesce) e poi clic sinistro sul punto di arrivo. Il pesce **va dritto**; se tocca un ostacolo **si ferma**.
    - Se si è fermato contro un'**alga** → `EATING`.
    - Se arriva sopra un **nido vuoto** ed è adulto → `FERTILIZING`.
    - Altrimenti resta fermo `idle_after_order_seconds` (2 s) e poi torna a `WANDER`.
  - `EATING`: dopo `eat_seconds` (3 s) l'alga viene rimossa e la fame si azzera. Poi torna a `WANDER`. *Un pesce circondato dalle alghe può uscirne mangiando.*
  - `FERTILIZING`: deve restare fermo sul nido `fertilize_seconds` (3 s). Se se ne va prima (nuovo ordine), la fecondazione non avviene. Se va a buon fine, il nido passa a `EGGS` e il pesce torna a `WANDER`, libero di andarsene.
- **Fame**: da 0 a `starve_seconds` (60 s). Barra visibile sopra il pesce quando supera il 50%. Al massimo il pesce muore.
- **Età**: nasce giovane e diventa fecondo dopo `maturity_seconds` (45 s). Il pesce giovane si riconosce a vista (sprite più piccolo).
- La velocità è ridotta dalla temperatura.

### 5.5 Nido
- Occupa **1 cella**. È un Area2D, quindi i pesci possono passarci sopra.
- Stati: `EMPTY` → (fecondazione) → `EGGS` → dopo `hatch_seconds` (20 s) nascono `hatch_count` (3) pesci giovani → `EMPTY`.
- Si ottiene dall'inventario con probabilità bassa (vedi §5.1).

## 6. Temperatura
- Valore normalizzato `T` da 0 a 1 (mostrato come °C sul termometro in alto a destra).
- **Sale sempre**: `dT/dt = temp_base_rate × (1 − coral_slowdown)`
  - `coral_slowdown = min(coralli_vivi × temp_slow_per_coral, temp_max_slowdown)` con `temp_max_slowdown` = 0.6, quindi la temperatura **non si ferma mai e non scende mai**.
  - `temp_base_rate` è tarato in modo che, senza coralli, si arrivi a T=1 in circa 8 minuti.
- Effetti (interpolazione lineare in base a T):

| Effetto | T = 0 | T = 1 |
|---|---|---|
| Intervallo di crescita alghe | 12 s | 4 s |
| Intervallo di spawn CO2 | 30 s | 8 s |
| Intervallo di spawn ciclone | 90 s | 30 s |
| Velocità pesci | 100% | 50% |

- Le buste di plastica hanno una frequenza fissa (`bag_spawn_interval` 40 s).

## 7. Minacce

Tutte le minacce sono **Area2D** che si muovono liberamente (non seguono la griglia) ed entrano dal bordo della mappa. Colpiscono un oggetto fermo quando la loro forma si sovrappone a una delle sue celle. **2.5 s prima** compare un **avviso** sul bordo (freccia/icona lampeggiante che indica direzione e tipo). Quando escono dalla mappa vengono rimosse.

### 7.1 CO2
- Nube (raggio 60 px), si muove **quasi dritta con curve casuali** (direzione + rumore sull'angolo).

### 7.2 Busta di plastica
- Lenta, si muove in modo **più casuale** della CO2 (cambi di direzione più ampi e frequenti).

### 7.3 Ciclone marino
- Raggio 40 px, veloce, va **dritto**.

## 8. Tabella delle interazioni

Le combinazioni non elencate **non fanno nulla**.

| Agente | Bersaglio | Effetto |
|---|---|---|
| Alga (espansione) | Corallo | Corallo −`algae_coral_damage` (10) ossigeno |
| CO2 | Corallo | Corallo −`co2_coral_dps` (25/s) ossigeno finché si sovrappongono |
| CO2 | Alga | La CO2 viene **assorbita** (sparisce) e l'alga **si espande subito** |
| CO2 | Nido con uova | Le uova muoiono, il nido torna `EMPTY` |
| Busta | Pesce | Il pesce **muore**, la busta resta |
| Busta | Corallo | Corallo −`bag_coral_damage` (35) ossigeno, la busta **sparisce** |
| Ciclone | Pesce / Alga | Distrutti |
| Ciclone | Nido | **Distrutto** |
| Ciclone | CO2 / Busta | Rimosse |
| Ciclone | Corallo | Il corallo **muore**, il ciclone **sparisce** |

Danni dal più debole al più forte: alga < busta < CO2.

## 9. Interfaccia
- **In alto a sinistra**: contatori di coralli, alghe, pesci e nidi; ognuno lampeggia in rosso quando è ≤ 1.
- **In alto a destra**: termometro.
- **In alto al centro**: punteggio / tempo.
- **In basso**: 4 slot dell'inventario, con il tempo di ricarica mostrato come radiale.
- **Pausa**: Spazio / Esc. Mentre sei in pausa non puoi piazzare oggetti.
- **Debug overlay** (F3): tutti i valori di bilanciamento in tempo reale, raggi di collisione, stati dei pesci.

## 10. Architettura Godot

```
ideologia_marina/
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
│   ├── ThreatSpawner.gd   # spawn + avvisi
│   ├── InventorySystem.gd
│   ├── PlacementController.gd
│   └── GridModel.gd       # occupazione celle: Dictionary[Vector2i → entità], cell↔world, adiacenti
├── entities/
│   ├── coral/  Coral.tscn  (StaticBody2D, layer CORAL)
│   ├── algae/  Algae.tscn  (StaticBody2D, layer ALGAE)
│   ├── fish/   Fish.tscn   (CharacterBody2D, layer FISH, mask WALL|CORAL|ALGAE)
│   ├── nest/   Nest.tscn   (Area2D, layer NEST)
│   └── threats/ CO2.tscn  Bag.tscn  Cyclone.tscn  (Area2D, layer THREAT)
├── levels/
│   └── Level01.tscn       # mappa iniziale fissa
├── ui/  HUD.tscn  Inventory.tscn  Thermometer.tscn  Warning.tscn  GameOver.tscn
└── main/ Main.tscn
```

**Physics layers**: 1 WALL, 2 CORAL, 3 ALGAE, 4 FISH, 5 NEST, 6 THREAT.

**Regole tecniche**:
- Nessun RigidBody: i pesci sono CharacterBody2D (`move_and_collide`), alghe e coralli sono StaticBody2D, nidi e minacce sono Area2D. Il comportamento resta controllabile.
- Ogni entità si registra in un gruppo (`corals`, `algae`, `fish`, `nests`) e `GameState` conta i membri dei gruppi.
- Espansione delle alghe e validità del piazzamento si leggono da `GridModel` (veloce, testabile senza scena). Solo il controllo "c'è un pesce o una minaccia sopra questa cella?" usa `PhysicsDirectSpaceState2D.intersect_shape`.
- Gli oggetti fermi si registrano in `GridModel` quando nascono e si rimuovono quando muoiono; la loro collisione fisica è costruita a partire dalle celle che occupano.
- Tutti i timer di gioco si basano sul `delta` del processo, così la pausa funziona con `get_tree().paused`.

## 11. Tappe

| # | Tappa | Risultato |
|---|---|---|
| M0 | Progetto (renderer Compatibility), Main, GridModel, Level01 fisso, muri, camera | scena vuota giocabile |
| M1 | Corallo + alga: espansione, ossigeno, recupero, sgretolamento | equilibrio alghe/coralli |
| M2 | Pesce: wander, selezione, ordine dritto, mangiare, fame | ciclo pesci–alghe |
| M3 | Nido: fecondazione, schiusa, maturità | ciclo di vita |
| M4 | Inventario + piazzamento + GameState + game over + punteggio | **prima build giocabile** |
| M5 | Minacce + avvisi + tabella delle interazioni | pressione esterna |
| M6 | Temperatura + rallentamento dai coralli | curva di difficoltà |
| M7 | Grafica, suoni, debug overlay, bilanciamento | rifinitura |

## 12. Domande aperte
- I parametri numerici sono solo un punto di partenza da verificare in playtest.
- `collapse_grace_seconds` (10 s) rispetto a `hatch_seconds` (20 s): con questi valori le uova salvano solo se sono state deposte almeno 10 s prima della morte dell'ultimo pesce. Va verificato in playtest.
- Il punteggio deve premiare i coralli vivi (es. punti/s = numero di coralli)?

# Ideologia Marina — Game Design Document (MVP)

> Game jam, tema **SUBIRE**. Gestionale real-time di una barriera corallina, vista dall'alto 2D, Godot 4.x (GDScript).
> Obiettivo: mantenere l'equilibrio dell'ecosistema il più a lungo possibile.

---

## 1. Pilastri

1. **Equilibrio**: ogni elemento serve, ogni eccesso fa danni. Se una popolazione arriva a zero, l'ecosistema collassa.
2. **Subire**: il corallo non fa niente, subisce e basta. Il giocatore lo protegge in modo indiretto.
3. **Real-time, spazio libero**: niente turni e niente caselle. Si usa la fisica 2D di Godot.

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
- **Game over** quando una di queste popolazioni **sulla mappa** arriva a 0: **coralli, alghe, pesci, nidi**.
- Parametro `collapse_grace_seconds` (default MVP: `0` = sconfitta immediata). Serve per provare, durante i test, un conto alla rovescia di recupero.
- **Punteggio** = secondi sopravvissuti (MVP). Mostrato nell'interfaccia e nella schermata di game over.

## 4. Mappa iniziale

Fissa, non randomica, costruita a mano nella scena `levels/Level01.tscn`:

- 3 pesci adulti (fecondi)
- 1 nido vuoto
- 5 alghe
- 5 coralli di forme diverse

Area di gioco delimitata da muri invisibili (StaticBody2D).

## 5. Elementi

### 5.1 Inventario
- **4 slot** fissi.
- Quando usi uno slot, lo slot si **ricarica dopo `slot_refill_seconds` (8 s)** con un oggetto estratto a caso con pesi:
  - Corallo: peso 50
  - Alga: peso 40
  - Nido: peso `nest_base_weight / (1 + nidi_in_mappa + nidi_in_inventario)` (base 20). Meno nidi hai, più è probabile che ne arrivi uno.
- Piazzamento: clicchi lo slot e compare un'anteprima trasparente sotto il mouse: **verde** se il punto è libero, **rossa** se si sovrappone a qualcosa. Clic sinistro conferma, clic destro o Esc annulla.
- Non si possono piazzare oggetti sopra altri oggetti o fuori dall'area di gioco.

### 5.2 Corallo — *subisce*
- Ha forme diverse (poligoni di collisione predefiniti, almeno 3 forme).
- È un ostacolo solido per i pesci.
- **Ossigeno** da 0 a 100. A 0 si **sgretola**: animazione, poi viene rimosso.
- **Recupero lento**: `+coral_regen_per_sec` (0.5/s) sempre.
- Danni (vedi tabella delle interazioni): alga che si espande addosso, CO2, busta, ciclone.
- Rallenta la salita della temperatura (§6).

### 5.3 Alga
- Corpo circolare (raggio `algae_radius` = 16 px), ostacolo solido per i pesci.
- **Espansione**: ogni `algae_growth_interval` (con variazione casuale ±20%, ridotto dalla temperatura) l'alga prova a generarne una nuova:
  1. sceglie una direzione a caso e un punto a distanza `algae_spawn_distance` (≈ 1.6 × raggio, così le alghe si sovrappongono un po' e i pesci non passano negli spazi tra loro);
  2. controlla il punto con una query di forma fisica:
     - **libero** → nasce la nuova alga;
     - **corallo** → l'alga non nasce, il corallo perde `algae_coral_damage` ossigeno;
     - **qualsiasi altra cosa** (alga, pesce, nido, muro, fuori mappa) → riprova con un'altra direzione, **al massimo 3 tentativi**, poi l'espansione fallisce.
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
- Area2D, i pesci possono passarci sopra.
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

Tutte le minacce sono **Area2D** che entrano dal bordo della mappa. **2.5 s prima** compare un **avviso** sul bordo (freccia/icona lampeggiante che indica direzione e tipo). Quando escono dalla mappa vengono rimosse.

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
│   └── PlacementController.gd
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
- Espansione delle alghe e validità del piazzamento: `PhysicsDirectSpaceState2D.intersect_shape`.
- Tutti i timer di gioco si basano sul `delta` del processo, così la pausa funziona con `get_tree().paused`.

## 11. Tappe

| # | Tappa | Risultato |
|---|---|---|
| M0 | Progetto, Main, Level01 fisso, muri, camera | scena vuota giocabile |
| M1 | Corallo + alga: espansione, ossigeno, recupero, sgretolamento | equilibrio alghe/coralli |
| M2 | Pesce: wander, selezione, ordine dritto, mangiare, fame | ciclo pesci–alghe |
| M3 | Nido: fecondazione, schiusa, maturità | ciclo di vita |
| M4 | Inventario + piazzamento + GameState + game over + punteggio | **prima build giocabile** |
| M5 | Minacce + avvisi + tabella delle interazioni | pressione esterna |
| M6 | Temperatura + rallentamento dai coralli | curva di difficoltà |
| M7 | Grafica, suoni, debug overlay, bilanciamento | rifinitura |

## 12. Domande aperte
- I parametri numerici sono solo un punto di partenza da verificare in playtest.
- `collapse_grace_seconds`: 0 (sconfitta immediata) oppure qualche secondo di conto alla rovescia?
- Il punteggio deve premiare i coralli vivi (es. punti/s = numero di coralli)?

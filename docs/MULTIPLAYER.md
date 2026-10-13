# Multiplayer guide (荣耀 Glory Arena)

Rongyao Arena is host-authoritative. One player hosts and simulates the whole match. Everyone else sends
input and renders what the host replicates. Empty slots are filled by AI bots (电脑 Bot). You can play
offline (单人练习 Solo vs Bots), with friends over Steam, or over a LAN or direct IP connection (ENet).

## 1. Playing with friends over Steam

Requirements:
- **Both players need the Steam client running and logged in** before starting the game. The game calls
  `steamInitEx(480)` at startup. The main menu shows the result at the bottom, either
  `Steam 已连接 Online: <name>` or `Steam 不可用 Unavailable ... - LAN only`.
- The game uses Steam's public test app **480 (Spacewar)**. You do not need to own anything: Spacewar is free
  for every Steam account. While you play, Steam shows you as "playing Spacewar". That is expected.
- Spacewar is shared by every developer in the world, so our lobbies carry the tag `game=rongyao_arena`. The
  browser only lists those lobbies.
- Two copies of the game on **one PC with one Steam account cannot connect to each other through Steam**.
  To test on one machine, use ENet (section 3).

Hosting:
1. Main menu, then **创建房间 Host (Steam)**. A public Steam lobby is created and you land in the lobby
   screen. It shows `Steam 大厅 Lobby <id>` in the top right.
2. Click **邀请好友 Invite Friends** to open the Steam overlay invite dialog, then pick friends. The overlay
   needs a windowed or fullscreen game, not headless. Shift+Tab also works.
3. Choose the mode (个人赛 Duel / 擂台赛 Group Arena / 团体赛 Team Battle / 副本 Raid), the map or raid,
   rounds, the time limit and the bot difficulty. Add or remove bots and set bot classes. Everyone picks a
   class in the class picker on the right.
4. When every player has pressed **准备 Ready**, press **开始比赛 Start Match**.

Joining:
- **Invite:** accept the invite in the Steam chat or overlay, or right-click your friend and choose "Join
  Game". If the game is already running, it leaves its current session and joins. If it is closed, Steam
  launches it with `+connect_lobby <id>` and it joins on startup.
- **Browse:** main menu, then **浏览房间 Browse Lobbies**, then **刷新 Refresh**, then **加入 Join**.

## 2. LAN / direct IP (ENet)

- Host: main menu, then **局域网 LAN Host/Join**, then **创建局域网房间 Host LAN**. The default port is
  **27777** (UDP). Open or forward it on the host's firewall or router for internet play.
- Join: type the host's IP address, for example `192.168.1.20`, then press **加入 Join**.
- Steam is not needed for LAN play. Start with `-- --no-steam` to skip Steam entirely.

## 3. Testing two instances on one PC (ENet)

Run two copies from PowerShell:
```powershell
& "K:/Godot_v4.7.2-stable_win64_console.exe" --path K:/Project/RONGYAO -- --no-steam
& "K:/Godot_v4.7.2-stable_win64_console.exe" --path K:/Project/RONGYAO -- --no-steam
```
1. In the first window, choose LAN, then Host LAN.
2. In the second window, choose LAN, set the address to `127.0.0.1`, then press Join.

In the Godot editor, Debug > Customize Run Instances does the same.

Automated headless check (host and client processes, lobby to match to results to lobby):
```powershell
$exe = "K:/Godot_v4.7.2-stable_win64_console.exe"
$h = Start-Process $exe -ArgumentList "--headless","--path","K:/Project/RONGYAO","-s","res://tests/test_net_enet.gd","--","--role=host","--no-steam" -PassThru -NoNewWindow -RedirectStandardOutput host.log
Start-Sleep 1.5
$c = Start-Process $exe -ArgumentList "--headless","--path","K:/Project/RONGYAO","-s","res://tests/test_net_enet.gd","--","--role=client","--no-steam" -PassThru -NoNewWindow -RedirectStandardOutput client.log
$h.WaitForExit(120000); $c.WaitForExit(20000)
foreach ($p in $h, $c) { if (-not $p.HasExited) { $p.Kill() } }   # only kill your own PIDs
Select-String "NET TESTS" host.log, client.log
```
The other NET tests:
- `tests/test_net_roster.gd`: roster and settings rules.
- `tests/test_net_solo.gd`: full offline flow (duel, arena, team, real kits and raid).
- `tests/test_net_e2e.gd`: every lobby option end to end with the real class kits: main menu and lobby load
  (class picker lists all 25 classes with CN/EN names, map lists only offer maps valid for the mode), then
  duel, arena, team 5v5 and raid each play to completion with bots only (`Engine.time_scale` 4, 30 s rounds),
  checking HUD binding, kill events, the boss bar, the result data on the results screen and the return to
  the lobby. Takes about 5 minutes, mostly the raid boss.
- `tests/test_net_steam.gd`: Steam lobby create, list and leave. It skips when Steam is not running.

## 4. What happens when someone leaves

- **A client leaves during a match:** the host turns their fighter into a bot (`BotBrain` in mode "pvp" or
  "raid"), and the match continues. Back in the lobby, the slot stays a bot.
- **A client leaves the lobby:** their slot is removed and a bot refills it.
- **The host leaves or crashes:** every client returns to the main menu with
  `主机已断开 Host disconnected`.
- **Joining while a match is running:** the host refuses the join with `比赛进行中 Match in progress`. A
  full lobby refuses it with `房间已满 Lobby is full`.

## 5. Architecture notes (for developers)

- `Net` (`autoload/net.gd`) handles transport only:
  - Steam init and lobbies (all Steam calls are dynamic, so the game runs without GodotSteam).
  - `SteamMultiplayerPeer.host_with_lobby` / `connect_to_lobby`.
  - ENet host and join.
  - `leave()`, which falls back to `OfflineMultiplayerPeer`.
  - Signals for the UI.
- `Game` (`autoload/game.gd`) owns `settings`, `roster`, preferences and the scene flow. Clients send
  `Game.request(op, args)` to the host. The host validates the request in `apply_op` and broadcasts
  `_rpc_sync(state)`.
- Match start sequence:
  1. `start_match()` sends an RPC that makes every peer load `scenes/match.tscn`.
  2. Each peer calls `Game.on_match_scene_ready()` once its scene is built.
  3. When all humans are ready (or after a 25 s timeout), the host calls `MatchScene.begin_match()`.
  4. `Match.begin()` spawns the fighters through `World`'s `MultiplayerSpawner`.
- Clients get the host-only fighter counters through `Match.stats`, which `match_pvp.gd` mirrors every second
  and on each death. Kills reach clients as `kill_event(victim_uid, killer_uid)`, which names the killer in
  the HUD kill feed. The raid clear timer and boss data come from `MatchRaid` (`timer_changed`,
  `score.boss_uid` / `phase` / `enraged`).
- The host validates the map before loading: `map_id` must be in `MapRegistry.for_mode(mode)` (else the
  mode's default) and `raid_id` must be in `RaidRegistry.ids()` (else the first raid).
- When the match ends, `Match.match_ended` shows the results screen on every peer. The HUD is hidden while
  the results screen is up. The host then calls
  `Game.return_to_lobby()`, either from the button or automatically after `Game.results_auto_return`
  seconds.
